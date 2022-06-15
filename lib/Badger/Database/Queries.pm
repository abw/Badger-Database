#========================================================================
#
# Badger::Database::Queries
#
# DESCRIPTION
#   Database query manager.  Can be used stand-alone or as a base class.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
# WORK IN PROGRESS
#   Made Badger::Factory a base class in an attempt to get query modules
#   loaded... currently working, but the original objective has failed.
#   The query() method need to replicate what the factory item() method
#   does.
#========================================================================

package Badger::Database::Queries;

use Badger::Database::Query;
use Badger::Factory::Class
    version      => 0.01,
    debug        => 0,
    base         => 'Badger::Database::Base',
    item         => 'query',
    path         => 'Badger::Database::Query BadgerX::Database::Query',
    utils        => 'is_object params',
    accessors    => 'engine',
#    hash_methods => 'queries fragments',
    hash_methods => 'fragments',
    words        => 'ARRAY HASH',
    import       => 'class',
    constant     => {
        AUTOGEN      => '_autogen',
        IS_NAME      => qr/^\w+$/,
        SQL_WILDCARD => '%',
    },
    config       => [
       'engine|class:ENGINE!',                           # mandatory engine object
       'query|query_module|class:QUERY|method:QUERY',    # query class
       'transaction|class:TRANSACTION',                  # transaction class
    ];

our $META_QUERIES = {
    column => 'SELECT <column> FROM <table>',
};

our $TRANSACTION = 'Badger::Database::Transaction';

*do = \&execute;


sub init {
    my ($self, $config) = @_;
    # We have to be careful because both Badger::Database and
    # Badger::Database::Table are subclasses and they're a bit fussy
    # about the order in which initialisation happens.  They like to
    # do their own configure() and then call init_queries() separately.
    $self->configure($config);
    $self->init_queries($config);
}

sub init_queries {
    my ($self, $config) = @_;

    # initialise the factory to define item/items and merge all $QUERIES
    # into $self->{ queries }
    $self->init_factory($config);

    # also add any $META_QUERIES
    $self->{ meta_queries } = $self->class->hash_vars(
        META_QUERIES => $config->{ meta_queries }
    );

    # same for any query $FRAGMENTS
    $self->{ fragments } = $self->class->hash_vars(
        FRAGMENTS => $config->{ fragments }
    );

    $self->debug("Initialised queries: ", $self->dump_data($self->{ queries }))
        if DEBUG;
}

sub prepare {
    shift->query(shift)->prepare(@_);
}

sub execute {
    shift->query(shift)->execute(@_);
}

sub row {
    shift->query(shift)->row(@_);
}

sub rows {
    shift->query(shift)->rows(@_);
}

sub query {
    my $self  = shift->prototype;
    my $query = shift;

    if (ref $query) {
        if (is_object($self->{ query }, $query)) {
            $self->debug("Found an existing query object: $query") if DEBUG;
            return $query;
        }
        else {
            # TODO: sth, B::DB::Query, etc.,
            return $self->todo('query refs');
        }
    }
    elsif ($query =~ /[^\w\.=]/) {        # TODO: why the '='?  Should it use IS_NAME?
        # $query contains non-word characters so it's "raw" SQL which we
        # don't cache once prepared
        $self->debug("Found raw SQL query: $query") if DEBUG;
        return $self->prepare_query($query);
    }
    elsif (my $sql = $self->{ queries }->{ $query }) {
        # an entry in the queries table can be a query module name
        if ($sql =~ /::/) {             # looks like a module name
            $sql =~ s/^:://;            # accept '::Module' for 'Module'
            $self->debug("Found a query module for $query: $sql") if DEBUG;
            return $self->prepare_query_module($sql);
        }

        # otherwise it's a named query which will be cached once prepared
        $self->debug("Found named query for $query\n") if DEBUG;

        return $self->{ query_cache }->{ $query } ||= do {
            $self->debug("Preparing query: $query => $sql\n") if DEBUG;
            $self->prepare_query($sql);
        };
    }
    elsif (my $module = $self->find($query)) {
        # found a module via Badger::Factory base class
        $self->debug("Found a query module for $query: $module") if DEBUG;
        return $self->prepare_query_module($module);
    }

    return $self->error_msg( bad_query => $query );
}

sub query_module {
    my $self   = shift;
    my $name   = shift;
    my $module = $self->find($name)
        || return $self->error_msg( bad_query => $name );
    return $self->prepare_query_module($module, @_);
}

sub prepare_query_module {
    my $self   = shift;
    my $module = shift;
    my $params = $self->query_params(@_);

    $self->debug(
        "preparing query module: $module with params: ",
        $self->dump_data($params)
    ) if DEBUG;

    # load module if necessary
    $self->{ loaded }->{ $module } ||= class($module)->load;

    $params->{ queries } = $self;
    $params->{ engine  } = $self->{ engine };

    return $module->new($params);
}

sub query_params {
    # subclasses can redefine this to inject query params
    my $self = shift;
    return params(@_);
}

sub select {
    my $self = shift;
    my $args;

    if (@_ == 1) {
        $args = ref $_[0] eq HASH
            ? shift
            : { select => shift };
    }
    else {
        $args = params(@_);
    }

    $self->query_module( select => $args );
}


sub prepare_query {
    my $self = shift;
    $self->debug_method( prepare_query => @_ ) if DEBUG;

    $self->{ query }->new(
        sql     => $self->prepare_sql(@_),
        engine  => $self->{ engine },
        queries => $self,
    );
}


sub prepare_meta_query {
    my $self = shift;
    my $type = shift;
    my $name = shift;
    my $frags = @_ && ref $_[0] eq HASH ? shift : { @_ };

    $self->debug_method( prepare_meta_query => $type, $name, $frags ) if DEBUG;

    # $name can be an array ref of name elements
    $name = join('_', AUTOGEN, $type, @$name)
        if ref $name eq ARRAY;

    # construct query from meta-query if we don't already have it cached
    return $self->{ query_cache }->{ $name } ||= do {
        my $meta = $self->{ meta_queries }->{ $type }
            || return $self->error_msg( bad_meta => $type );
        $self->debug("preparing meta query ($type): $meta") if DEBUG;
        $self->prepare_query($meta, $frags);
    };
}


sub wildcard_starting {
    my ($self, $value) = @_;
    return $value . SQL_WILDCARD;
}

sub wildcard_containing {
    my ($self, $value) = @_;
    return SQL_WILDCARD . $value . SQL_WILDCARD;
}

sub wildcard_ending {
    my ($self, $value) = @_;
    return SQL_WILDCARD . $value;
}


#-----------------------------------------------------------------------------
# SQL generation
#-----------------------------------------------------------------------------

sub prepare_sql {
    shift->expand_fragments(@_);
}

sub expand_fragments {
    my $self   = shift;
    my $sql    = shift;
    my $params = params(@_);

    # Each query subclass can define its own set of SQL fragments,
    # along with any that are provided by the user as config params.
    my $frags = $self->fragments;

    # a set of user-defined fragments can also be passed to the method
    $params ||= { };

    $self->debug(
        "Expanding fragments in query: $sql\n",
        " fragments: ", $self->dump_data($frags), "\n",
        " params: ", $self->dump_data($params), "\n"
    ) if DEBUG;

    my $n = 16;
    1 while $n-- && $sql =~
        s/
            # accept fragments like <keys> <?keys> and <keys=?>
            < (\?? \w+ (=\?)?) >
        /
            $params->{ $1 }     # user-defined fragment
         || $frags->{ $1 }      # table-specific fragment
         || return $self->error_msg( bad_sql_frag => $1 => $sql )
        /gex;

    # cleanup any excessive whitespace
    $sql =~ s/\n(\s*\n)+/\n/g;
    $self->debug("Expanded fragments in query: $sql\n")
        if DEBUG;

    return $sql;
}


sub column {
    my $self  = shift;
    my $query = shift;
    if ($query =~ IS_NAME) {
        # $q->column('foo') is sugar for $q->column('SELECT foo FROM <table>')
        $query = $self->prepare_meta_query(
            # This looks weird.  The first arg is name of meta query, then
            # a list ref of columns we're operating on.  The remaining
            # arguments are the fragments to expand, which happen to be
            # 'column', which expands to the column name in $query
            column => [$query],     # this is weird - first arg is meta query
            column => $query,       # name, then list ref of columns, followe
        );
    }
    $self->query($query)->column(@_);
}

sub dbh {
    shift->engine->dbh;
}


#-----------------------------------------------------------------------------
# Transactions
#-----------------------------------------------------------------------------

sub begin_work {
    shift->dbh->begin_work
}

sub commit {
    shift->dbh->commit
}

sub rollback {
    shift->dbh->rollback
}

sub transaction {
    my $self  = shift;
    my $that  = shift || $self;     # allows objects other than $self to be wrapped
    my $class = $self->{ transaction };

    $self->debug("preparing transaction module: $class") if DEBUG;

    # load module if necessary
    $self->{ loaded }->{ $class } ||= class($class)->load;

    # create new transaction nomad wrapped around $self
    return $class->new($that, @_);
}


sub destroy {
    my $self = shift;
    my $msg  = shift || '';
    my ($queries, $query);

    $self->debug(
        "Destroying queries",
        length $msg ? " ($msg)" : ''
    ) if DEBUG;

    # destroy any cache queries
    $queries = delete $self->{ query_cache };
    foreach $query (values %$queries) {
        $query->destroy if $query;
    }
    %$query = ();

    # delete engine reference
    delete $self->{ engine };

    return $self;
}


sub DESTROY {
    shift->destroy('object destroyed');
}

1;

1;

=head1 NAME

Badger::Database::Queries - database query manager.

=head1 DESCRIPTION

This module is a manger for database queries.  It can be
used stand-alone or as a base class for table modules.

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt>.

=head1 COPYRIGHT

Copyright (C) 2005-2022 Andy Wardley.  All Rights Reserved.

=head1 SEE ALSO

L<Badger::Database::Query>

=cut
