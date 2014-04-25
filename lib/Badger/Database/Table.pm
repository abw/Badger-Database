#========================================================================
#
# Badger::Database::Table
#
# DESCRIPTION
#   An abstraction of a database table.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Database::Table;

use Badger::Class
    version     => 0.02,
    debug       => 0,
    base        => 'Badger::Database::Queries',
    constants   => 'ARRAY HASH DELIMITER PKG',
    utils       => 'is_object self_params params',
    import      => 'class',
    throws      => 'database.table',  # IMPORTANT because we redefine id()
    words       => 'SCHEMA no_id',
    accessors   => 'engine table id field fields updates',
    constant    => {
        AUTOGEN  => '_autogen',
    },
    messages    => {
        not_found => 'Not found in %s: %s',
    },
    config      => [
        'table|name|class:TABLE:NAME!',
        'id|id_field|serial|class:ID:SERIAL',
        'keys|key|key_field|key_fields|class:KEY:KEYS',
        'fields|class:FIELDS',
        'valid|class:VALID',
        'select|selectable|class:SELECT',
        'update|updateable|class:UPDATE',
        'record|record_module|class:RECORD',
        'record_base|method:RECORD',
#       'columns|class:COLUMNS',            # TODO
    ];


our @SCHEMA_KEYS = qw(
    table record key keys field fields columns valid update methods
);

our $QUERIES = {
    fetch_all => 'SELECT <columns> FROM <table>',
};

our $META_QUERIES = {
    insert  => 'INSERT INTO <table> (<fields>) VALUES (<values>)',
    update  => 'UPDATE <table> SET <set> WHERE <where>',
    delete  => 'DELETE FROM <table> WHERE <where>',
    fetch   => 'SELECT <columns> FROM <table> WHERE <where>',
    order   => 'SELECT <columns> FROM <table> WHERE <where> <order>',
};

*name = \&table;

sub init {
    my ($self, $config) = @_;

    # Initialise the table schema
    $self->init_schema($config);

    # Let the Badger::Database::Queries base class initialiase queries
    $self->init_queries($config);

    return $self;
}

sub init_schema {
    my ($self, $config) = @_;
    my $class  = $self->class;
    my $schema = $class->hash_vars(SCHEMA);

    $self->debug("schema: ", $self->dump_data($schema)) if DEBUG;

    # merge any $SCHEMA definition into $config
    $config = { %$schema, %$config } if $schema;

    $self->debug("config data: ", $self->dump_data($config)) if DEBUG;

    # configure $self from $config
    $self->configure($config);

    # optional model ref which gives us access to other tables
    my $model = $self->{ model } = $config->{ model };

    # mandatory database handle...
    my $engine = $self->{ engine } = $config->{ engine }
        || ( $model
                ? $model->engine
                : $self->error_msg( no_engine => $self->{ table } )
           );

    # ... must be a Badger::Database::Engine object or subclass
    return $self->error_msg( invalid => engine => $engine )
        unless is_object($self->ENGINE, $engine);

    # primary key or keys
    my $keys = $self->{ keys } || [ ];
    $keys = [ split DELIMITER, $keys ] unless ref $keys eq ARRAY;
    $self->{ keys } = $keys;

    # add any id key to the start of the keys list (which is usually empty
    # if id is defined, but provides us with a canonical list either way)
    unshift(@$keys, $self->{ id }) if $self->{ id };

    # other non-key fields
    my $fields = $self->{ fields } || [ ];
    $fields = [ split DELIMITER, $fields ] unless ref $fields eq ARRAY;
    $self->{ fields } = $fields;

    # fields we're allowed to select, we store a list in 'selects' (note
    # plural, in keeping with 'keys', 'fields', etc) and also have a 'select'
    # hash table (along with 'key', 'field', etc') for fast set inclusion tests
    # NOTE: this isn't in use... yet
    my $selects = $self->{ select } || [ ];
    $selects = [ split DELIMITER, $selects ] unless ref $selects eq ARRAY;
    $self->{ selects } = $selects;

    # fields we're allowed to update, we store a list in 'updates'/'update' as
    # per 'selects'/'select'
    my $updates = $self->{ update } || [ ];
    $updates = [ split DELIMITER, $updates ] unless ref $updates eq ARRAY;
    $self->{ updates } = $updates;

    # additional valid fields, used by link tables.
    my $valid = $self->{ valid } || [ ];
    $valid = [ split DELIMITER, $valid ] unless ref $valid eq ARRAY;

    # construct hash arrays to lookup valid fields quickly
    $self->{ key     } = { map { ($_ => 1) } @$keys };
    $self->{ field   } = { map { ($_ => 1) } @$fields };
    $self->{ valid   } = { map { ($_ => 1) } (@$keys, @$fields, @$valid) };
    $self->{ update  } = { map { ($_ => 1) } @$updates };
    $self->{ columns } = [ @$keys, @$fields ];

    $self->debug("valid keys: ", $self->dump_data($self->{ valid })) if DEBUG;

    # The class name of the record object that we turn database records into
    my $record = $self->{ record };
    if ($record) {
        if (! ref $record) {
            # load a specific record module, e.g. MyProject::Table::User
            $self->debug("Loading $self->{ table } record module: $record") if DEBUG;
            class($record)->load;
        }
        # Trying out idea to allow record to define a Badger::Class config
        #        elsif (ref $record eq HASH)
        #            my $recparams = $record;
        #            $record = delete $recparams->{ class } || $self->record_subclass($self->{ table });
        #            my $rclass = class($record);
        #            $recparams->{ base } ||= $self->{ record_base };
        #            $rclass->export($rclass->name, [ %$recparams ]);
        #
        else {
            return $self->error_msg( bad_record => $self->{ table }, $record );
        }
    }
    else {
        $record = $self->record_subclass($self->{ table });
        $self->debug("Creating record subclass for $self->{ table }: $record") if DEBUG;
        class($record)->base( $self->{ record_base } );
    }
    $self->{ record } = $record;

    # any methods we want auto-generated for the record class are inherited
    # from all base classes, making it possible to create a restricted base
    # class table with limited record methods, which can be subclassed to
    # add further methods for more permissive usage.
    $self->{ methods } = $class->hash_vars(
        METHODS => $config->{ methods }, $config->{ relations }
    );

    return $self;
}

sub schema {
    my $self = shift;
    return $self->{ schema } ||= {
        map { ($_, $self->{ $_ }) }
        @SCHEMA_KEYS
    };
}

sub record_subclass {
    my ($self, $table) = @_;

    # generate the name of a subclass of the record_base class with a unique
    # name based on the names of the database and table,
    #   e.g. Badger::Database::Record::_autogen::mydb::users

    join(
        PKG,
        $self->{ record_base },
        AUTOGEN,
        $self->{ engine }->safe_name,
        $table
    );
}

sub record {
    my $self   = shift;
    my $args   = @_ && ref $_[0] eq HASH ? shift : { @_ };
    my $record = $self->{ record } || return $args;
    $args->{ _table } = $self;
    $args->{ _model } = $self->{ model };

    # Be careful to check the result is defined, and not just true.
    # A record could have an auto-stringification/numification operator
    # overloaded which returns a false result
    my $result = $record->new($args);

    return defined $result
        ? $result
        : $self->error_msg( new_record => $record, $record->error );
}

sub records {
    my $self   = shift;
    my $args   = @_ && ref $_[0] eq ARRAY ? shift : [@_];
    return [ map { $self->record($_) } @$args ];
}

sub row_record {
    my $self = shift;
    my $row  = $self->row(@_) || return;
    return $self->record($row);
}


sub rows_records {
    my $self = shift;
    my $rows = $self->rows(@_) || return;
    return @$rows
        ? $self->records($rows)
        : $rows;        # an empty list of rows === an empty list of records
}

sub fragments {
    my $self = shift;

    # If called with multiple arguments then we delegate to the fragments()
    # method in the Badger::Database::Queries subclass, which is a regular
    # hash accessor/mutator method generated by Badger::Class::Methods.
    # This will update the $self->{ fragments }, but we need to make sure
    # that we regenerate the $self->{ all_fragments } which contains
    # additional fragments specific to the the table.
    if (@_) {
        $self->SUPER::fragments(@_);
        delete $self->{ all_fragments };
    }

    return $self->{ all_fragments } ||= do {
        my $table_frags  = $self->table_fragments;
        my $config_frags = $self->{ fragments };
        my $merged_frags = {
            %$table_frags,
            %$config_frags,
        };
        $self->debug(
            "Merged all fragments: ",
            $self->dump_data($merged_frags)
        ) if DEBUG;
        $merged_frags;
    };
}

sub table_fragments {
    my $self = shift;

    return $self->{ table_fragments } ||= do {
        my ($keys, $fields) = @$self{ qw( keys fields ) };
        my $table = $self->{ table };
        my $frags = {
            table       => $table,
            id          => $self->{ id },
            keys        => join(', ', @$keys),
            fields      => join(', ', @$fields),
            columns     => join(', ', map { "`$_`" } @$keys, @$fields),
            tcolumns    => join(', ', map { "`$table`.`$_`" } @$keys, @$fields),
            '?keys'     => join(', ', map { '?' } @$keys),
            '?fields'   => join(', ', map { '?' } @$fields),
            '?columns'  => join(', ', map { '?' } @$keys, @$fields),
            'keys=?'    => join(' AND ', map { "$_=?" } @$keys),
        };
        $frags->{ key   } = $frags->{ keys };
        $frags->{'key=?'} = $frags->{'keys=?'};
        $frags;
    };
}

sub query_params {
    my $self = shift;
    my $params;

    # Note sure about this... it's really a special case for select so we
    # can write $table->select('id,name') as short-hand for
    # $table->select( columns => 'id,name' ).  Oh well, I'll leave it for
    # now and see how it pans out in testing...

    if (@_ == 1) {
        $params = ref $_[0] eq HASH
            ? shift
            : { columns => shift };
    }
    else {
        $params = { @_ };
    }

    $params->{ table } ||= $self->{ table };

    return $params;
}


#-----------------------------------------------------------------------
# insert methods
#-----------------------------------------------------------------------

sub insert {
    my $self   = shift;
    my $args   = $self->method_args( insert => @_ );
    my @fields = $self->method_fields( insert => $args );

    $self->debug_method( insert => $args ) if DEBUG;

    return $self->error_msg( no_fields => insert => $self->{ table } )
        unless @fields;

    $self->debug("valid fields for insert: ", join(', ', @fields), "\n") if DEBUG;

    my $query = $self->prepare_meta_query(
        insert => \@fields,
        fields => join(', ', map {"`$_`"} @fields),
        values => join(', ', ('?') x scalar(@fields)),
    );

    my $sth = $query->execute( @$args{ @fields } );

    $args->{ $self->{ id } } = $self->insert_id($sth)
        if $self->{ id };

    return $self->inserted($args);
}

*inserted = \&record;

sub insert_id {
    my $self = shift;

    return $self->error_msg(no_id)
        unless $self->{ id };

    return $self->{ engine }->insert_id(
        $self->{ table },
        $self->{ id },
        @_
    );
}


#-----------------------------------------------------------------------
# update methods
#-----------------------------------------------------------------------

sub update {
    my $self   = shift;
    my $args   = $self->method_args( update => @_ );
    my @kvals  = $self->method_key_values( update => $args );
    my @keys   = @{ $self->{ keys } };
    my $update = $self->{ update };
    my (@fields, @values);

    $self->debug_method( update => $args ) if DEBUG;

    # grok the names of all the fields that have been specified as arguments
    # that can be updated and aren't listed as keys (which we'll be using
    # to identify the record to update)
    @fields = grep { $update->{ $_ } && ! $self->{ key }->{ $_ } } keys %$args;

    return $self->error_msg( no_fields => update => $self->{ table } )
        unless @fields;

    @values = @$args{ @fields, @keys };

    my $query  = $self->prepare_meta_query(
        update => [@fields, @keys],
        set    => join(', ', map { "`$_`=?" } @fields),
        where  => $self->where_clause(@keys),
    );

    $self->debug(
        " update: (", join(', ', @fields), ")\n",
        "  where: (", join(', ', @keys), ")\n",
        " values: (", join(', ', @values), ")\n",
        "  query: ", $query->sql, "\n",
    ) if DEBUG;

    $query->execute(@values);
}


#-----------------------------------------------------------------------
# delete method
#-----------------------------------------------------------------------

sub delete {
    my $self  = shift;
    my $args  = $self->method_args( delete => @_ );
    my @kvals = $self->method_key_values( delete => $args );
    my $keys  = $self->{ keys };
    my $ident;

    $self->debug_method( delete => $args ) if DEBUG;

    my $query  = $self->prepare_meta_query(
        delete => $keys,
        where  => $self->where_clause(@$keys),
    );

    return $query->execute(@kvals)
        || return $self->not_found( $args, @kvals );
}


#-----------------------------------------------------------------------
# fetch methods
#-----------------------------------------------------------------------

sub fetch_row {
    my $self    = shift;
    my $args    = $self->method_args( fetch => @_ );
    my @fields  = $self->method_fields( fetch => $args );
    my $table   = $self->{ table };
    my $query   = $self->prepare_meta_query(
        fetch   => \@fields,
        where   => $self->where_clause(@fields),
    );

    $self->debug("fetch query: ", $query->sql, @$args{ @fields }) if DEBUG;

    return $query->row( @$args{ @fields } )
        || return $self->not_found( $args, @fields );
}

sub fetch_one_row {
    my $self = shift;
    # TODO: should we check we don't get more than one?
    return $self->fetch_row(@_)
        || $self->error( $self->reason );
}

sub fetch_all_rows {
    my $self    = shift;
    my $args    = $self->method_args( fetch_all => @_ );
    my @fields  = %$args ? $self->method_fields( fetch_all => $args ) : ();
    my $table   = $self->{ table };
    my ($query, $rows, $order, $oname, $where);

    if (@fields) {
        # TODO: handle order/group properly - or delegate to query at a
        # higher/deeper level

        $where = $self->where_clause(@fields);

        if ($order = $args->{ order }) {
            $oname = $order;
            $oname =~ s/\W+/_/g;   # allow for "fieldname DESC"
            $oname = "_order=$oname";
            $query = $self->prepare_meta_query(
                order => [@fields, $oname],
                where => $where,
                order => "ORDER BY $order",
            );
            $self->debug("prepared meta-query for ordered fetch (query:order): ", $query->sql) if DEBUG;
        }
        else {
            $query = $self->prepare_meta_query(
                fetch => \@fields,
                where => $where,
            );
            $self->debug("prepared meta-query for unordered fetch (query:fetch): ", $query->sql) if DEBUG;
        }


        $rows = $query->rows( @$args{ @fields } )
            || return $self->not_found( $args, @fields );
    }
    else {
        # return all rows if there are no (valid) search fields defined
        $self->debug("fetch_all() fetching all records\n") if $DEBUG;
        $rows = $self->rows('fetch_all')
            || return $self->decline_msg( not_found => $self->{ table } => 'fetch_all' );
    }

    return $rows;
}


sub fetch {
    my $self = shift;
    my $row  = $self->fetch_row(@_) || return;
    return $self->record($row);
}

sub fetch_one {
    my $self = shift;
    my $row  = $self->fetch_one_row(@_) || return;
    return $self->record($row);
}

sub fetch_all {
    my $self    = shift;
    my $rows = $self->fetch_all_rows(@_) || return;
    return $self->records($rows);
}


#-----------------------------------------------------------------------
# methods for examining and manipulating arguments for other methods
#-----------------------------------------------------------------------

sub method_args {
    my $self   = shift;
    my $method = shift;
    my $args;

#    $self->debug("[$self] [$method] ARGS: ", join(', ', @_));

    if (@_ == 1) {
        if (ref $_[0] eq HASH) {
            # single hash ref contains named params
            $args = shift;
        }
        elsif ($self->{ id }) {
            # single argument is an id... (if we have one)
            $args = {
                $self->{ id } => shift,
            };
        }
        elsif (@{ $self->{ keys } } == 1) {
            # ...or a single key
            $args = {
                $self->{ keys }->[0] => shift,
            };
        }
        else {
            return $self->error_msg( bad_args => $method => $_[0] );
        }
    }
    else {
        use Badger::Debug 'debug_caller';
        if (@_ % 2) {
            $self->debug_caller('method_args');
        }
        # otherwise gobble multiple args up as named params
        $args = { @_ };
    }

    return $args;
}

sub method_key_values {
    my ($self, $method, $args)  = @_;
    my $keys = $self->{ keys };
    my ($key, $value, @values);

    return $self->error_msg( no_ident => $method => $self->{ table } )
        unless @$keys;

    # return a value from $args foreach $key in keys
    foreach $key (@$keys) {
        return $self->error_msg( no_param => $key => $method => $self->{ table } )
            unless defined ($value = $args->{ $key });
        push(@values, $value);
    }

    return wantarray
        ?  @values
        : \@values;
}

sub method_fields {
    my ($self, $method, $args)  = @_;
    my $valid  = $self->{ valid };
#    $self->debug('valid: ', $self->dump_data($valid));
    my @fields = sort grep { $valid->{ $_ } } keys %$args;
#    $self->debug('fields: ', $self->dump_data(\@fields));

    return $self->error_msg( no_fields => $method => $self->{ table } )
        unless @fields;

    return wantarray
        ?  @fields
        : \@fields;
}


# put this down at the bottom so Perl doesn't get confused when we use
# core 'keys' in the code above

sub keys {
    $_[0]->{ keys };
}

sub key {
    my $self = shift;

    if (@_) {
        # lookup key by name
        return $self->{ key }->{ shift };
    }
    else {
        # return the name of the auto-incremented id column if there is one
        return $self->{ id } if $self->{ id };

        # return the one and only key, barfing if @$keys != 1
        my $keys = $self->{ keys };
        return @$keys > 1 ? $self->error_msg( multi_keys => $self->{ table } )
             : @$keys < 1 ? $self->error_msg( no_keys    => $self->{ table } )
             : $keys->[0];
    }
}

sub has {
    my ($self, $name) = @_;
    return $self->{ valid }->{ $name };
}

sub has_key {
    my ($self, $name) = @_;
    return $self->{ key }->{ $name };
}

sub has_field {
    my ($self, $name) = @_;
    return $self->{ field }->{ $name };
}

sub has_relation {
    my ($self, $name) = @_;
    return $self->{ method }->{ $name };
}

sub model {
    return $_[0]->{ model }
       ||= $_[0]->error('No model defined');
}

sub hub {
    return $_[0]->{ hub }
       ||= $_[0]->model->hub;
}

sub where_clause {
    my $self  = shift;
    my $table = $self->{ table };
    return join(
        ' AND ',
        map { /\./ ? "$_=?" : "$table.$_=?" }
        @_
    );
}

sub not_found {
    my ($self, $args, @fields) = @_;
    @fields = @{ $fields[0] } if @fields == 1 && ref $fields[0] eq ARRAY;
    my $keys = join(
        ', ',
        map  { "$_ => " . (defined $args->{ $_ } ? $args->{ $_ } : '<undef>') }
        grep { defined $_ }
        @fields
    );
    return $self->decline_msg( not_found => $self->{ table } => $keys );
}

sub debug_method {
    my ($self, $method, @args) = @_;
    $self->debug(
        $method, '(',
        join(', ', map { $self->dump_data($_) } @args),
        ') from ', $self->{ table }
    );
}


1;


__END__

=head1 NAME

Badger::Database::Table - database table abstraction module

=head1 SYNOPSIS

    # define a subclass
    package Badger::Widgets;
    use base 'Badger::Database::Table';
    use Badger::Widget;

    our $TABLE    = 'example';
    our $KEYS     = [ qw( id ) ];     # auto-generated by database
    our $FIELDS   = [ qw( name type ) ];
    our $RECORD   = 'Badger::Widget';

    # now use it
    package main;
    use Badger;

    # get a Badger::Database object
    my $database = Badger->database({
        type => 'mysql',
        name => 'badger',
        user => 'nigel',
        pass => 'top_secret',
    });

    # get a Badger::Database::Model wrapper for the database
    my $model = Badger->model( database => $database );

    # now create the table object
    my $e  = Badger::Database::Table::Example->new({
        model => $model,
    });

    # create a record and corresponding object
    my $record = $example->create({
        name => 'Thingy123',
        type => 'Widget',
    });
    print "added record: ", $record->id(), "\n";

    # fetch a record as an object
    my $record = $example->fetch( id => 12345 );
    print "fetched record: ", $record->id(), "\n";

    # update a record
    $example->update( id => 12345, name => 'Thingy235' );

    # delete a record
    $example->delete( id => 12345 );

=head1 DESCRIPTION

This module implements a base class object providing an interface to a
Badger database table. It is designed to be subclassed to provide
access to specific tables in the database.

NOTE: this documentation needs to be updated to reflect recent changes and
enhancements to this module.

=head2 Writing a Database Table Module

Here's a complete example showing how we would write a database table
module as a subclass of C<Badger::Database::Table>. In this case, we'll
implememt the fictional C<Badger::Widgets> module.

    package Badger::Widgets;
    use base 'Badger::Database::Table';

    use strict;
    use warnings;
    use Badger::Widget;

    our $VERSION  = 0.01;
    our $DEBUG    = 0 unless defined $DEBUG;

    # database table and fields
    our $TABLE    = 'widget';
    our $KEYS     = [ qw( id ) ];
    our $FIELDS   = [ qw( name price ) ];

    # object to turn database records into
    our $RECORD   = 'Badger::Widget';

That's all there is to it.  There are no additional methods defined
in this simple example, just the relevant bits of information that
the C<Badger::Database::Table> base class needs to perform the basic
operations.

The first two few lines define the package name and indicate that it is a
subclass of L<Badger::Database::Table>.

    package Badger::Widgets;
    use base 'Badger::Database::Table';

We then enable strict mode and all warnings, as all good Perl modules do.
We also load the C<Badger::Widget> module (also fictional) which will be
used to create objects from database records.  This should be a subclass
module derived from L<Badger::Database::Record>.

    use strict;
    use warnings;
    use Badger::Widget;

The C<$VERSION> variable defines a version number for our module and C<$DEBUG>
defines a debugging flag, set to 0 unless something else (i.e. a user script)
has explicitly set it otherwise.

    our $VERSION  = 0.01;
    our $DEBUG    = 0 unless defined $DEBUG;

The C<$TABLE> variable defines the database table name.

    our $TABLE    = 'widget';

C<$KEYS> is a reference to a list of one or more fields that comprise
the primary key for the table.  In this case we have just one primary
key field, C<id>.

    our $KEYS     = [ qw( id ) ];

C<$FIELDS> is a reference to a list of any other fields you want to read
from or write to that database table. You don't have to list all the
fields in the table, just those you are interested in.

    our $FIELDS   = [ qw( name price ) ];

Finally, the C<$RECORD> variable specifies the object class (i.e. the
name of your module) that should be used to create objects representing
the records of the database. This is the same module
(C<Badger::Widget>) that we loaded earlier in the example. It should be
implemented as a subclass of L<Badger::Database::Record>.

    our $RECORD   = 'Badger::Widget';

With those definitions in place, the base class methods inherited from
L<Badger::Database::Table> can figure out enough about the database to
perform basic L<create()>, L<exists()>, L<fetch()>, L<update()> and
L<delete()> operations.

=head2 Initialising a Database Table Module

When you create a new object derived from a C<Badger::Database::Table>,
you must provide a reference to a L<Badger::Database::Model> object as the
C<model> parameter. The model implements a collection of all the different
table objects defined in the system (at least, the ones it knows about).
It also has a reference to a L<Badger::Database> object for the underlying
database connection via C<DBI>.

Instead of mucking around creating all those objects manually, use the
L<Badger> module as a convenient front-end.

    use Badger;
    use Badger::Widgets;

    # create a Badger object with the required db info
    my $badger = Badger->new(
        database => {
            type => 'mysql',
            name => 'badger',
            user => 'nigel',
            pass => 'top_secret',
        }
    );

    # now get a model
    my $model = $badger->model();

    # create your table object, passing the model ref
    my $widgets = Badger::Widgets->new( model => $model );

In the long term, you'll probably want to add your C<Badger::Widgets> module
to the list of table modules defined in the L<Badger::Database::Model>. Then
you can make life even easier by leaving the model to load your module and
create a new object with the correct arguments.

    use Badger;
    my $widgets = Badger->model->widgets();

You may even want to add a C<widgets()> method to the L<Badger> module.

    use Badger;
    my $widgets = Badger->widgets();

It doesn't get any easier than that. Not without neural implants.

=head2 Using a Database Table Module

So by one of the approaches outline above, we now have a reference
to a C<Badger::Widgets> object, C<$widgets>.

    my $widgets = Daily->widgets();

The C<create()> method inserts a new database record and returns
a C<Badger::Widget> object containing all the field data.  Any
default data provided by the database will also be present in the
object returned.

If, for example, our C<widget> table uses an C<AUTO_INCREMENT> to
generate a unique C<id> for the widget, then we can call L<create()>
to insert the record, and then call the L<id()> method on the object
returned to determine the identifier that was assigned to it.

    $widget = $widgets->create({
        name  => 'example',
        price => 12.99
    });
    print "created widget id: ", $widget->id(), "\n";

The C<fetch()> method can be used to fetch a widget by its
primary key.

    $widget = $widgets->fetch(123);         # positional args
    $widget = $widgets->fetch(id => 123);   # named args

The C<update()> method allows you to update a record.

    $widgets->update({
        id    => 123,
        price => 13.99,
    });

The C<delete()> method allows you to delete a record.

    $widgets->delete(123);
    $widgets->delete(id => 123);

=head2 Writing Custom Database Table Methods

If you need to do anything more complicated then you'll need to write your own
custom methods for L<create()>, L<fetch()>, and so on. Here's an example (a
fictional C<Example::Merchants> module) where we want to support different
search parameters. In this case, a merchant can be specified by numerical
identifier or their realm (a URI).

    package Example::Merchants;
    use Example::Merchant;
    use base 'Badger::Database::Table';

    # ...the usual pre-amble...
    our $TABLE     = 'merchant';
    our $KEYS      = [ qw( id ) ];
    our $FIELDS    = [ qw( realm name merchant customer ) ];
    our $COLUMNS   = join(', ', @$KEYS, @$FIELDS);

    # define our record object class
    our $RECORD = 'Example::Merchant';

    # define some database queries
    our $QUERIES = {
        fetch_id    => "SELECT $COLUMNS FROM $TABLE WHERE id=?",
        fetch_realm => "SELECT $COLUMNS FROM $TABLE WHERE realm=?",
    };

    # define some error messages
    our $MESSAGES = {
        no_key  => "no 'id' or 'realm' parameter specified to %s",
    }

We define the SQL queries we're going to use up front.  This makes it easy
to see at a glance what the different queries a module uses and keeps them
all in the same place so that they're easy to edit should the database schema
change (as it sometimes does during development).  We also define an error
message format that we'll want to use in several places.  It's also a good
idea to define things like this up front.  It makes it easier to change them
en-masse (e.g. when you need to localise the application to another language).

    sub fetch {
        my $self = shift;
        my $args = $self->args(@_);
        my $db   = $self->{ database };
        my ($key, $row);

        if ($key = $args->{ id }) {
            $row = $db->row( $QUERIES->{ fetch_id }, $key ) || return;
        }
        elsif ($key = $args->{ realm }) {
            $row = $db->row( $QUERIES->{ fetch_realm }, $key ) || return;
        }
        else {
            return $self->error_msg( no_key => 'fetch' );
        }
        return $self->record($row);
    }

Our custom C<fetch()> method first calls the C<args()> method to parse any
arguments provided. We'll use this logic in other methods (like C<exists()> and
C<delete()>) so it makes good sense to extract it out into a separate method.
We'll have a look at the C<args()> method shortly. For now, all you need to
know is that it returns a reference to a hash array containing an C<id> or
C<realm> item.

Either way, we call the C<row()> method on the L<Badger::Database>
object stored in our C<$self->{ database }> value (C<$db>). If we got
passed an C<id> parameter then we use the query in
C<$QUERIES-E<gt>{ fetch_id }>:

    SELECT $COLUMNS FROM $TABLE WHERE id=?

If instead we get a C<realm> parameter then we use
C<$QUERIES-E<gt>{ fetch_realm }>:

    SELECT $COLUMNS FROM $TABLE WHERE realm=?

If we don't get either C<id> or C<realm> then we throw an error using the
message format we defined earlier. We provide it with the parameter it
requires to complete the message (inserted by C<sprintf()> to replace to the
C<%s> in the message format - see L<Badger::Base> for details).

    ...else {
        return $self->error_msg( no_key => 'fetch' );
    }

In this case, the error message thrown would be:

    no 'id' or 'realm' parameter specified to fetch

The final thing the method does, assuming it does successfully fetch a
record from the database, is to call the C<record()> method to convert the
C<$data> hash reference into an C<Example::Merchant> object, as
defined by our C<$RECORD> package variable.

    return $self->record($row);

Here's the C<args()> method that handles the arguments passed to the
C<fetch()> method.

    sub args {
        my $self = shift; my $args;
        if (@_ == 1) {
            if (ref $_[0] eq 'HASH') {
                # single hash ref contains named params
                $args = shift;
            }
            elsif ($_[0] =~ /^\d+/) {
                # single numerical argument is an id
                $args = {
                    id => shift,
                };
            }
            else {
                # otherwise single argument is a uri
                $args = {
                    realm => shift,
                };
            }
        }
        else {
            # otherwise gobble multiple args up as named params
            $args = { @_ };
        }
        # accept 'uri' as an alias for 'realm'
        $args->{ realm } ||= $args->{ uri };
        return $args;
    }

There's quite a lot to it, but that's really only because it's trying to be
as flexible as possible to make life easy for the end user.  It allows you
to specify a single parameter which can be a numeric id or a realm URI:

    $merchants->fetch(123);
    $merchants->fetch('http://example.co.uk/');

It also allows you to use named parameters:

    $merchants->fetch( id => 123 );
    $merchants->fetch( realm => 'http://example.co.uk/' );

Or pass a reference to a hash of named parameters:

    $merchants->fetch({ id => 123 });
    $merchants->fetch({ realm => 'http://example.co.uk/' });

Here's another example of a C<create()> method which validates the
arguments passed and provides defaults for those unspecified.  First
we have the relevant parts of the module pre-amble:

    package Example::Orders;
    use base 'Badger::Database::Table';
    use Example::Order;

    # ..etc...

    our $TABLE   = 'orders';
    our $KEYS    = [ qw( id ) ];
    our $FIELDS  = [ qw( customer amount currency exchange status date) ];
    our $FLIST   = join(', ', @$FIELDS);
    our $VLIST   = join(', ', map { '?' } @$FIELDS);
    our $RECORD  = 'Example::Order';
    our $QUERIES = {
        insert => "INSERT INTO $TABLE ($FLIST) VALUES ($VLIST)",
    };
    our $MESSAGES = {
        insert_failed => 'failed to insert order database record: %s',
        no_customer   => 'no customer specified to %s',
        no_amount     => 'no amount specified to %s',
    };

Notice how we create C<$FLIST> and C<$VLIST> and then insert them into the
query (and any other queries that require them).  It's a lot neater and easier
to understand at a glance than the verbose version:

    insert => "INSERT INTO $TABLE
               (customer, amount, currency, exchange, status, date)
               VALUES
               (?, ?, ?, ?, ?, ?)",

It's also less error-prone if you have to add or delete fields.  Just change the
C<$FIELDS> definition and let the code ripple the changes through.  Small things
like this can make a big different when you multiply it out to a dozen or so
queries.

So now here's the C<create()> method that uses the C<insert> query.

    sub create {
        my $self = shift;
        my $args = $self->args(@_);
        my $db   = $self->{ database };

        # check we got a customer reference and amount
        return $self->error_msg( no_customer => 'create' )
            unless $args->{ customer };
        return $self->error_msg( no_amount => 'create' )
            unless $args->{ amount };

        # set defaults for date and status
        my $currency = $self->hub->config->currency();
        $args->{ status   } ||= 'pending';
        $args->{ date     } ||= $self->date_today();

        # run the query
        $db->query( $QUERIES->{ insert },
                    @$args{ @$FIELDS } )
            || return $self->error_msg(insert_failed => $db->error());

        $args->{ id } = $self->insert_id() || return;

        return $self->record($args);
    }

We again use a custom C<args()> method to handle our arguments. Then we check
that C<customer> and C<amount> arguments have been provided:

    # check we got a customer reference and amount
    return $self->error_msg( no_customer => 'create' )
        unless $args->{ customer };
    return $self->error_msg( no_amount => 'create' )
        unless $args->{ amount };

Then we set defaults for the C<status> and C<date> fields. We get the
default date from a separate C<date_today()> method. It save us clogging
up our method up with messy C<localtime()> code, and the name of the
method makes it immediately obvious what it's doing (a good example of
"self-documenting code").

    $args->{ status   } ||= 'pending';
    $args->{ date     } ||= $self->date_today();

Then we run the C<insert> query grepping out all the revelant arguments that
match the field names defined in C<$FIELDS>.  We're careful to report back
any error straight away.

    # run the query
    $db->query( $QUERIES->{ insert },
                @$args{ @$FIELDS } )
        || return $self->error_msg( insert_failed => $db->error());

Then we call the C<insert_id()> method to fetch the insert ID of the
record just inserted and add it to our hash of arguments.

    $args->{ id } = $self->insert_id() || return;

Finally we call the C<record()> method to turn our arguments into an
C<Example::Order> database record object object for us to return.

    return $self->record($args);

If you need to do anything special when you turn database records into objects
then you can implement your own L<record()> method.

=head1 METHODS

All of the methods listed that accept parameters can be passed a
reference to a hash array or a list of named parameters.

    # list of named parameters
    $table->method( name => $value );

    # hash reference of named parameters
    $table->method({ name => $value });

=head2 new()

Constructor method.

    my $table    = Badger::Database::Table->new({
        model => $database,
        table    => 'widgets',
        keys     => ['id'],
        fields   => ['name', 'password'],
        record   => 'Badger::Widget',
    });

Accepts the following configuration parameters.

=head3 model

A reference to a L<Badger::Database::Model> object.

=head3 database

A reference to a L<Badger::Database> object. If unspecified it defaults
to the database that the model is using (fetched via a call to
C<$model-E<gt>database()>).

=head3 table

The name of the database table. Defaults to the table name specified in
the C<$TABLE> package variable, as defined by subclass modules.

=head3 keys

A reference to a list of key fields in the table. Defaults to the list
of keys defined in the C<$KEYS> package variable.

=head3 fields

A reference to a list of non-key fields in the table. Defaults to the
list of keys defined in the C<$FIELDS> package variable.

=head3 record

The class name of a L<Badger::Database::Record> subclass which is used to
represent individual records in the database table. Defaults to the
value defined in the C<$RECORD> package variable.

=head2 database()

Returns a reference to the L<Badger::Database> object provided by the
C<database> configuration parameter passed to the constructor method.

=head2 record(%fields)

Creates a database record object to represent a particular record in the
database table. This will be an object of the class defined in the
C<record> configuration parameter or the C<$RECORD> package variable.

    my $record = $table->record({
        id  => '12345',
        foo => 'The foo value',
        bar => 'The bar value',
        baz => 'The baz value',
    });

=head2 create(%data)

Create a new database table record and corresponding object.

    my $record = $table->create({
        id  => '12345',
        foo => 'The foo value',
        bar => 'The bar value',
        baz => 'The baz value',
    });

=head2 exists(%data)

Returns true if the specified record exists, false if it doesn't.

    print "Record $id already exists\n"
        if $table->exists( id => $id )

=head2 fetch(%data)

Fetch a record from the database table and return an object representing
it.

    my $record = $table->fetch( id => 12345 );

=head2 update(%data)

Update an existing record in the database.

    $table->update({
        id  => 12345,
        foo => 'The new foo value',
    });

=head2 delete(%data)

Delete a record from the database.

    $table->delete( id => 12345 );

=head2 store(%data)

Store a record in the database table, creating it if it doesn't exists
and updating it if it does.

    $table->store( id => 12345, name => 'Thingy768' );

=head2 instance(%data)

Fetch an existing record from the database table or create a new one if it
doesn't already exists.

    my $record = $table->instance({
        id  => '12345',
        foo => 'The foo value',
        bar => 'The bar value',
        baz => 'The baz value',
    });

=head2 insert_id()

Returns the identifier assigned to an inserted record.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2005-2009 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
