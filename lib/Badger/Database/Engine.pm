package Badger::Database::Engine;

use DBI;
use Badger::Class
    version     => 0.01,
    debug       => 0,
    base        => 'Badger::Database::Base',
    import      => 'class',
    accessors   => 'driver database host port',
    utils       => 'is_object weaken',
    words       => 'no_dbh no_query SERIAL',
    constants   => 'ARRAY HASH SPACE',
    constant    => {
        UNDEF        => '<undef>',
        ANON         => '_anon',
        STH          => 'DBI::st',
        # used to generate CREATE TABLE queries - see Badger::Test::Database
        SERIAL_TYPE  => 'SERIAL',
        SERIAL_REF   => 'BIGINT UNSIGNED',
    },
    vars        => {
        OPTIONS => {
            RaiseError => 0,
            PrintError => 0,
        }
    },
    methods     => {
        type    => \&driver,
        name    => \&database,
        user    => \&username,
        pass    => \&password,
        dbh     => \&connect,
    },
    config      => [
        'dbh',
        'dsn',
        'options',
        'database|name!',
        'driver|type|class:DRIVER|method:DRIVER!',
        'username|user',
        'password|pass',
        'host|class:HOST',
        'port|class:PORT',
    ];

#-----------------------------------------------------------------------
# initialisation and connection methods
#-----------------------------------------------------------------------

sub init {
    my ($self, $config) = @_;

    # merge all $OPTIONS pkg vars into any user-supplied options
    $config->{ options } = $self->class->hash_vars(
        OPTIONS => $config->{ options }
    );

    $self->debug("merged options: ", $self->dump_data($config->{ options }))
        if DEBUG;

    # merge all configuration options into $self
    $self->configure($config);

    # if we've got a dbh at this point then it was passed to us, so
    # we mustn't disconnect the dbh when we're done.
    $self->{ shared_dbh } = $self->{ dbh };

    # connect to database (nullop if we already have a dbh)
    $self->connect;

    return $self;
}


sub connect {
    my $self = shift;
    $self->debug("connect()\n") if DEBUG;

    # connect to db and cache handle for subsequent use
    return $self->{ dbh } ||= $self->connector->();
}


sub connector {
    my $self = shift;

    # We don't want to leave sensitive information like the username and
    # and password stored in the object in case it gets exposed somewhere
    # it shouldn't (e.g. by Data::Dumper or something similar).  However,
    # we can't connect to the database and then throw the credentials away
    # in case we need to re-connect later (e.g. when using MySQL over a
    # TCP/IP connection and the connection gets dropped).  So we create a
    # closure which makes the connection for us using a lexical copy of
    # the credentials.  Short of disassembling the code, there's no way
    # to retrieve the username/password from the closure, but we can use
    # it as many times as we need to create a connection.

    return $self->{ connector } ||= do {
        my $dsn  = $self->dsn;
        my $user = delete $self->{ username };
        my $pass = delete $self->{ password };
        my $opts = $self->{ options } || { };
        my $this = $self;
        weaken $this;

        $self->debug("Creating connector to $dsn\n") if DEBUG;

        sub {
            $this->debug(
                "Connecting to $dsn\n",
                "   user: ", $user || UNDEF, "\n",
                "   pass: ", $pass || UNDEF, "\n",
                "   opts: ", $this->dump_data_inline($opts), "\n"
            ) if DEBUG;

            DBI->connect($dsn, $user, $pass, $opts)
                || return $this->error_msg( dbi => connect => $DBI::errstr );
        };
    };
}


sub disconnect {
    my $self = shift;
    my $msg  = shift || '';
    my ($cache, $sth, $dbh);

    $self->debug(
        $self->{ shared_dbh }
            ? "NOT disconnecting from database (shared dbh): $self->{ database }" :
        $self->{ dbh }
            ? "Disconnecting from database $self->{ database }"
            : "No database connection to disconnect",
        length $msg ? " ($msg)" : ''
    ) if DEBUG;

    # It's safe to disconnect the database unless we were passed
    # in the $dbh as a parameter, in which case we leave it alone
    $dbh->disconnect
        if ($dbh = delete $self->{ dbh })
              && ! delete $self->{ shared_dbh };

    return $self;
}


sub reconnect {
    shift->disconnect->connect;
}


sub dsn {
    my $self = shift;

    return $self->{ dsn } ||= do {
        my ($name, $host, $port) = @$self{ qw( database host port ) };
        $host .= ":$port"  if $host && $port;
        $name .= "\@$host" if $host;
        join(':', 'DBI', $self->{ driver }, $name);
    };
}


#-----------------------------------------------------------------------
# query methods
#-----------------------------------------------------------------------

sub query {
    my $self = shift;
    my $sql  = shift || return $self->error_msg(no_query);
    my $sth  = $self->prepare($sql);

    $self->debug(
        'query(', $sql,
        @_ ? ', ' . join(', ', map { $self->dump_data_inline($_) } @_)
           : '',
        ") => $sth"
    ) if DEBUG;

    $self->execute($sth, @_)
        || $self->error_msg( dbi => execute => $sth->errstr );

    return $sth;
}


sub prepare {
    my $self = shift;
    my $sql  = shift || return $self->error_msg(no_query);;

    $self->debug("prepare($sql)\n") if DEBUG;

    if (is_object(STH, $sql)) {
        return $sql;
    }
    else {
        my $dbh = $self->{ dbh } || $self->connect;
        return $dbh->prepare($sql)
            || $self->error_msg( dbi => prepare => $dbh->errstr );
    }
}


sub execute_query {
    my $self  = shift;
    my $query = shift;
    $self->execute($query->sth, @_);
}


sub execute {
    my $self = shift;
    my $sth  = shift;

    $self->debug(
        'execute(', $sth,
        @_ ? ', ' . join(', ', map { $self->dump_data_inline($_) } @_)
           : '',
        ')'
    ) if DEBUG;

    if (grep { ref($_) } @_) {
        my $n = 1;
        my ($arg, $cfg);

        # bind parameters to query, where each parameter is either a
        # simple value, a reference to a hash (see DBI bind_param())
        # or a reference to an array like [$arg, SQL_INTEGER] or
        # [$arg, { TYPE => SQL_INTEGER } ]
        # TODO: figure out if this persists past the execute()

        while (@_) {
            $arg = shift @_;
            if (ref $arg eq ARRAY) {
                # e.g.
                ($arg, $cfg) = @$arg;
                $sth->bind_param($n++, $arg, $cfg)
                    || return $self->error_msg( dbi => bind_param => $sth->errstr );
            }
            elsif (@_ && ref $_[0] eq HASH) {
                $cfg = shift @_;
                $sth->bind_param($n++, $arg, $cfg)
                    || return $self->error_msg( dbi => bind_param => $sth->errstr );
            }
            else {
                $sth->bind_param($n++, $arg)
                    || return $self->error_msg( dbi => bind_param => $sth->errstr );
            }
        }
    }

    no warnings 'uninitialized';        # DBI bug?

    $self->debug("executing query") if DEBUG;

    return $sth->execute(@_)
        ? $sth
        : $self->error_msg( dbi => execute => $sth->errstr );
}


#-----------------------------------------------------------------------
# miscellaneous methods
#-----------------------------------------------------------------------

sub quote {
    shift->{ dbh }->quote(@_);
}


sub insert_id {
    my ($self, $table, $field, $sth) = @_;

    my $dbh = $self->{ dbh }
        || return $self->error_msg(no_dbh);

    # this won't work in all cases, but it's probably the best shot
    return $dbh->last_insert_id(undef, undef, $table, $field)
        || $self->error_msg( insert_id => $table, $field, $dbh->errstr );
}


sub safe_name {
    my $self = shift;
    my $name = $self->{ database };

    # the database name can be a file path (e.g. for SQLite) or something
    # else with weird characters, so we'll try and sanitise it.

    $name =~ s/\W+$//;          # chomp any non-word chars from end
    $name =
        ($name =~ /([\w\.]+)$/)
            ? $1                # match word.word.word.etc at end
            : ANON;             # or use anonymous name
    $name =~ s/\./_/g;          # convert . to _

    return $name;
}


sub DESTROY {
    shift->disconnect('object destroyed')
}


1;

=head1 NAME

Badger::Database::Engine - base class database engine

=head1 SYNOPSIS

    # using a subclass of Badger::Database::Engine, e.g. for MySQL
    use Badger::Database::Engine::Mysql;

    my $engine = Badger::Database::Engine::Mysql->new(
        database => 'testdb',
        username => 'tester',
        password => 's3kr1t',
    );

    # separate prepare()/execute()
    my $sth = $engine->prepare('SELECT * FROM users WHERE id=?');
    $engine->execute($sth, 42);

    # combined prepare()/execute()
    my $sth = $engine->query('SELECT * FROM users WHERE id=?', 42);

=head1 DESCRIPTION

This module is a base class database engine for running queries against a
database. Subclasses of this module specialise it further for different
databases, e.g. L<Badger::Database::Engine::Mysql>,
L<Badger::Database::Engine::Postgres> and L<Badger::Database::Engine::SQLite>.

An engine has a number of configuration parameters that tell it how to connect
to the underlying database.

    use Badger::Database::Engine::Mysql;

    my $engine = Badger::Database::Engine::Mysql->new(
        database => 'testdb',
        username => 'tester',
        password => 's3kr1t',
    );

However, you shouldn't ever need to create or use an engine object directly as
one is created implicitly by the L<Badger::Database> front-end module. All of
the L<CONFIGURATION OPTIONS> described below can be passed to the
L<Badger::Database> L<new()|Badger::Database/new()> constructor method and
will be automatically forwarded to the engine's L<new()> constructor method.

    use Badger::Database;

    my $db = Badger::Database->new(
        engine   => 'mysql',
        database => 'testdb',
        username => 'tester',
        password => 's3kr1t',
    );

If you really do want a reference to the engine running behind the scenes
then you can call the L<engine()|Badger::Database/engine()> method.

    my $engine = $db->engine;

=head1 CONFIGURATION OPTIONS

=head2 database / name

The name of the database that the engine should connect to.  This parameter
is mandatory.

=head2 username / user

An optional user name for accessing the database.

=head2 password / pass

An optional password for accessing the database.

=head2 host

An optional host name on which the database is running.

=head2 port

An optional port number to connect to the database.

=head2 options

An optional hash reference of L<DBI> configuration options.

    my $db = Badger::Database->new(
        engine   => 'mysql',
        database => 'testdb',
        options  => {
            RaiseError => 1,
            PrintError => 1,
        }
    );

=head2 dsn

A complete L<DBI> connection string in Data Source Notation.  This is
generated automatically from the other parameters if not defined.

=head2 dbh

A reference to an existing L<DBI> database handle.  The engine will
I<not> automatically disconnect this handle.

=head2 safe_name

Returns a sanitised version of the database name suitable for use as a
Perl identifier.  For MySQL and Postgres, the name returned will be the
same value as for L<database>.

=head1 METHODS

=head2 new(\%config)

Constructor method used to create an engine object connected to an underlying
database.  See L<CONFIGURATION OPTIONS> for details of the configuration
options supported.

=head2 query($sql,@args)

Method to prepare and execute a database query.  The first argument is a
SQL query string or pre-prepared L<DBI> statement handle.  Any further
arguments represent placeholder values.

    my $sth = $engine->query('SELECT * FROM users WHERE id=?', 42);

=head2 prepare($sql)

Method to prepare a database query.

    my $sth = $engine->query('SELECT * FROM users WHERE id=?');

=head2 execute($sth,@args)

Method to execute a pre-prepared database query.  The first argument is
a L<DBI> statement handle, as returned by a previous call to L<prepare()>.
Any further arguments are used as placeholder values

    $engine->execute($sth, 42);

=head2 quote()

A short-cut to the C<quote()> method provided by L<DBI> for quoting values.

=head2 insert_id()

Returns the record identifier generated by a previous insert into a table
with a primary key automatically generated from a sequence.

=head2 driver

Returns the name of the L<DBI> driver (subclass of L<DBI::DBD>) that the
engine uses.

=head2 database

Returns the database name as specified by the L<database> configuration
parameter.

=head2 host

Returns the database host as specified by the L<host> configuration option.

=head2 port

Returns the database port as specified by the L<port> configuration option.

=head1 INTERNAL METHODS

=head2 init()

Initialisation method which configures the engine object and calls the
internal L<connect()> method to establish a connection to the database.

=head2 connect()

Internal method used to connect to the database

=head2 disconnect()

Internal method used to disconnect from the database.

=head2 reconnect()

Internal method used to disconnect from the database and then reconnect
to it.

=head2 connector()

Internal method used to generate a connector subroutine.  By hiding the
L<username> and L<password> parameters inside a closure, we effectively
prevent any inspection via casual snooping, while retaining the ability
to reconnect the database as required.

=head2 dsn()

Internal method used to generate the DSN (Data Source Notation) string
required by L<DBI>.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2005-2014 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Database>,
L<Badger::Database::Engines>,
L<Badger::Database::Engine::Mysql>,
L<Badger::Database::Engine::Postgres>,
L<Badger::Database::Engine::SQLite>.

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
