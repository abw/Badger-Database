package Badger::Database;

use DBI;
use Badger::Debug ':dump :debug';
use Badger::Database::Engines;
use Badger::Database::Model;
use Badger::Class
    debug     => 0,
    base      => 'Badger::Database::Queries Badger::Prototype',
    import    => 'class',
    accessors => 'database host port',
    utils     => 'self_params',
    constants => 'ARRAY HASH PKG',
    constant  => {
        DB      => 'Badger::Database',
        ENGINES => 'Badger::Database::Engines',
        MODEL   => 'Badger::Database::Model',
        AUTOGEN => '_autogen',
    },
    exports   => {
        any   => 'DB',
    },
    config    => [
       'dsn',                                    # optional dsn
       'hub',                                    # optional hub reference
       'options',                                # DBI option (rename to dbi_options?)
       'engine|class:ENGINE!',                   # mandatory engine type
       'driver|type|class:DRIVER',               # optional driver, to override engine
       'database|name|class:DATABASE!',          # mandatory name of database
       'username|user|class:USERNAME',           # optional login credentials and
       'password|pass|class:PASSWORD',           # connection details...
       'host|class:HOST',
       'port|class:PORT',
       'model|class:MODEL|method:MODEL!',        # name of model class
       'table|class:TABLE',                      # optional name of table class
     ];

our $VERSION = 0.03;                    # for ExtUtils::MakeMaker

class->methods(
    name => \&database,
);


sub init {
    my ($self, $config) = @_;

    # init_engine() can do some extra massaging of $config
    $self->init_engine($config);
    $self->init_model($config);

    # now call configure() again to merge config into $self
    $self->configure($config);

    # initialise the queries base class
    $self->init_queries($config);

    return $self;
}


sub init_engine {
    my ($self, $config) = @_;

    $self->debug("init()") if DEBUG;

    if (my $dbh = $config->{ dbh }) {
        $config->{ engine   } ||= $dbh->{ Driver }->{ Name };
        $config->{ database } ||= $dbh->{ Name };
    }

    # Have the configure() method populate the $config hash with any
    # default items instead of $self.  This is so that we can pass all
    # the configuration items over to the engine module and any other
    # delegate components
    $self->configure( $config => $config );

    # have the engine shed prepare an engine for us to use
    $config->{ engine } = $self->engine(
        $config->{ engine },
        $config,
    );
}

sub init_model {
    my ($self, $config) = @_;

    # merge any table/record definitions in database package into config
    $config->{ tables  } = $self->class->hash_vars( TABLES  => $config->{ tables  } );
    $config->{ records } = $self->class->hash_vars( RECORDS => $config->{ records } );

    # create a model to manage any table definitions
    $config->{ model } = $self->new_model($config);
    $self->debug("model now set to $config->{model}") if DEBUG;
}

sub engine {
    my $self = shift;
    return @_
        ? $self->ENGINES->engine(@_)
        : $self->prototype->{ engine };
}

sub dbh {
    shift->engine->dbh;
}

sub model {
    my $self = shift;
    $self->debug("model()") if DEBUG;

    if (@_) {
        return $self->new_model(@_);
    }
    else {
        $self->debug("Returning prototype model for [$self]") if DEBUG;
        return $self->prototype->{ model };
    }
}

sub model_class {
    my ($self, $params) = self_params(@_);

    my $engine = $params->{ engine }
        ||= $self->engine
        ||  return $self->error_msg( missing => 'engine' );

    # Models autogenerate methods to access tables on demand.  To avoid
    # cross-pollution between two or more active models accessing different
    # databases, we create a dynamic subclass of Badger::Database::Model
    # with a name based on the database name,
    #   e.g. Badger::Database::Model::_autogen::mydb
    my $modclass = $self->MODEL;
    my $subclass = join(
        PKG,
        $modclass,
        AUTOGEN,
        $engine->safe_name,
    );
    class($subclass)->base($modclass);

    return $subclass;
}

sub new_model {
    my ($self, $params) = self_params(@_);
    my $modclass = $self->model_class($params);
    $self->debug("Creating new $modclass model: ", $self->dump_data($params)) if DEBUG;
    return $modclass->new($params);
}

sub table {
    shift->model->table(@_);
}

sub tables {
    shift->model->tables(@_);
}

sub insert_id {
    shift->engine->insert_id(@_);
}

sub fragments {
    my $self = shift;

    # If called with multiple arguments then we delegate to the fragments()
    # method in the Badger::Database::Queries subclass, which is a regular
    # hash accessor/mutator method generated by Badger::Class::Methods.
    # This will update the $self->{ fragments }, but we need to make sure
    # that we regenerate the $self->{ all_fragments } which contains
    # additional fragments specific to the database.
    if (@_) {
        $self->SUPER::fragments(@_);
        delete $self->{ all_fragments };
    }

    return $self->{ all_fragments } ||= do {
        my $dbase_frags  = $self->database_fragments;
        my $config_frags = $self->{ fragments };
        my $merged_frags = {
            %$dbase_frags,
            %$config_frags,
        };
        $self->debug(
            "Merged all fragments: ",
            $self->dump_data($merged_frags)
        ) if DEBUG;
        $merged_frags;
    };
}

sub database_fragments {
    my $self = shift;

    return $self->{ database_fragments } ||= do {
        my $engine = $self->{ engine };
        {
            serial_type => $engine->SERIAL_TYPE,
            serial_ref  => $engine->SERIAL_REF,
        };
    };
}

sub disconnect {
    shift->engine->disconnect;
}

sub destroy {
    my $self = shift;
    my $msg  = shift || '';

    $self->debug(
        "Destroying database",
        length $msg ? " ($msg)" : ''
    ) if DEBUG;

    $msg = 'database destroyed';

    # save engine reference before B::DB::Queries has a chance to delete it
    my $engine = $self->engine;

    # call Badger::Database::Queries base class destroy() to free queries
    $self->SUPER::destroy($msg);

    # call model's destroy() to free model, tables, queries, etc.
    my $model = delete $self->{ model };
    $model->destroy($msg) if $model;

    # disconnect engine and delete reference
    $engine->disconnect if $engine;
    delete $self->{ engine };
}


1;


=head1 NAME

Badger::Database - database abstraction module

=head1 SYNOPSIS

    use Badger::Database;

    my $db = Badger::Database->new(
        engine   => 'mysql',
        database => 'badger',
        username => 'nigel',
        password => 's3kr1t',
    );

    # fetch single row
    my $user = $db->row('SELECT * FROM user WHERE id=?', 42);
    print $user->{ name };

    # fetch list of rows
    my $users = $db->rows('SELECT * FROM users');
    foreach $user (@$users) {
        print $user->{ name };
    }

    # create query object
    my $user_by_id = $db->query('SELECT * FROM user WHERE id=?');

    # execute several times
    $user = $user_by_id->row(42);
    $user = $user_by_id->row(43);
    $user = $user_by_id->row(44);
    # ...etc...

    # defining named queries
    $db->queries(
        user_by_id      => 'SELECT * FROM user WHERE id=?',
        user_by_name    => 'SELECT * FROM user WHERE name=?',
        users_by_status => "SELECT * FROM user WHERE status=?",
    );

    # using named queries
    $user  = $db->row( user_by_id => 42 );
    $user  = $db->row( user_by_name => 42 );
    $users = $db->rows( users_by_status => 'active' );
    $users = $db->rows( users_by_status => 'pending' );

    # alternate way of using named queries
    my $query = $db->query('user_by_id');
    $user = $query->row(42);

    # defining tables
    $db->tables(
        users  => {
            table   => 'users',
            id      => 'id',          # SERIAL identifier generated by DB
            fields  => 'name email',  # other fields to read
            update  => 'name',        # fields that can be updated
            queries => {              # define table-specific queries
                by_name => 'SELECT <columns>
                            FROM   <table>
                            WHERE  name=?'
            },
        },
    );

    # using a table
    my $users = $db->table('users');

    # inserting a record
    my $user = $users->insert(
        name  => 'Arthur Dent',
        email => 'dent@badgerpower.com',
    );

    # low-level prepare/execute just like DBI
    my $sth = $db->prepare('SELECT * FROM users');

    # returns regular DBI statement handle
    $sth->execute() || die $sth->errstr;
    my $user = $sth->fetchrow_hashref;
    print $user->{ name };

    # or all-in-one prepare/execute
    $sth  = $db->execute('SELECT * FROM users');
    $user = $sth->fetchrow_hashref;
    print $user->{ name };

=head1 DESCRIPTION

=head2 INTRODUCTION

The C<Badger::Database> module provides a simple, useful and moderately
powerful interface to SQL databases, implemented as a thin wrapper around the
L<DBI> module and related L<DBI::DBD> modules.

It is derived from the DBI plugin module for the L<Template Toolkit|Template>,
originally written by Simon Matthews in 2000. I rewrote it as stand-alone
module in 2005 and started using it in a number of projects. It then proceeded
to grow in various different directions up until 2008 when I finally got a
chance to rein it it, clean it up and make it suitable for general release as
part of the L<Badger> collective.

During that time there has been much activity in the Perl community and a
number of other fine database modules have sprung into existence. This begs
the question: "Why do we need another one?".

The short answer to that question is that I already had the code, was using it
regularly, found it useful and convenient, and thought other people might too.
That's not to say that there aren't more extensive and/or mature solutions out
there now that you should be using instead. C<Badger::Database> is
I<different>, not necessarily any I<better>.

C<Badger::Database> aims for convenience over complexity. It has a very
shallow learning curve that allows you to use it without having to first
master any complex concepts.  If you're already familiar with the basics
of using L<DBI> then C<Badger::Database> is no harder, and in some cases,
even easier.

It does not set out to be a full-blown Object/Relational Mapping tool (ORM),
nor does it go to great lengths to protect you from having to write SQL
queries. That said, it I<does> have some level of support for both of those
kinds of functionality, and more. We're happy to aim for the 80/20 sweet spot
- if we can easily automate 80% of the more menial tasks then it leaves you
free to concentrate on the remaining 20%.

If you're looking for a full-blown ORM and don't mind a slightly steeper
learning curve then you should consider using L<DBIx::Class> or L<Rose::DB>
instead. The L<Fey> modules also look interesting in terms of robust SQL
generation, although I haven't had the chance to use them in anger.

C<Badger::Database> currently supports MySQL, SQLite and Postgres databases.
Adding support for other database engines is a relatively simple process.

=head2 CONNECTING TO A DATABASE

Create a new C<Badger::Database> object to connect to an existing database.

    use Badger::Database;

    my $db = Badger::Database->new(
        engine   => 'mysql',
        database => 'badger',
        username => 'nigel',
        password => 's3kr1t',
    );

The C<engine> parameter corresponds to a L<Badger::Database::Engine> module
which abstracts some of the various subtle differences between different
databases.  The C<database> parameter is the name of the database.  The
optional C<username> and C<password> parameters can be used to supply the
relevant credentials if your database requires them.

The C<Badger::Database> module will automatically connect to the database
via a L<Badger::Database::Engine> module.  The database will be disconnected
automatically when the C<Badger::Database> object goes out of scope and is
garbage collected.

Alternately, you can provide a reference to an existing L<DBI> database
handle.  In this case the database connection will not be closed
automatically when the C<Badger::Database> object goes out of scope.

    my $dbh = DBI->connect(...);
    my $db  = Badger::Database(
        dbh => $dbh
    );

=head2 RUNNING DBI QUERIES

The C<Badger::Database> module provides method for making queries that
map directly onto the underlying L<DBI> implementation.  You can use
the L<prepare()> method to prepare a SQL query into a L<DBI> statement
handle.

    my $sth = $db->prepare('SELECT * FROM users WHERE status=?');

You can then execute the query and call methods on the statement handle
as usual.

    # execute query to fetch users with 'active' status
    $sth->execute('active') || die $sth->errstr;

    # fetch row from result
    my $user = $sth->fetchrow_hashref;
    print $user->{ name };

There is also the all-in-one L<execute()> method.

    $sth  = $db->execute('SELECT * FROM users WHERE status=?', 'active');
    $user = $sth->fetchrow_hashref;
    print $user->{ name };

The L<dbh()> method returns the current L<DBI> database handle in case you
want to access any of its other methods.

    $dbh  = $db->dbh;

You'll notice that C<Badger::Database> doesn't attempt to obscure the
underlying L<DBI> implementation from you.  If you already know the basics
of using L<DBI> then you can start using C<Badger::Database> and work up
to the more advanced concepts at your own pace.

=head2 QUERY OBJECTS

The L<query()> method can be used to create a L<Badger::Database::Query>
object. This is a thin wrapper around a L<DBI> statement handle, with some
extra methods of convenience.

    my $query = $db->query('SELECT * FROM users WHERE status=?');

You can call the L<execute()|Badger::Database::Query/execute()> method on it,
just as you would on a naked L<DBI> statement handle. In fact it returns the
L<DBI> statement handle so that you can retrieve data from it.

    my $sth  = $query->execute('active');
    my $rows = $sth->fetchall_hashref;

If you want to execute a query and fetch all rows returned by it, as shown in
the example above, then you can call the
L<rows()|Badger::Database::Query/rows()> method as a shortcut.

    my $query = $db->query('SELECT * FROM users WHERE status=?');
    my $rows  = $query->rows('active');

If you just want a single row then you can call the
L<row()|Badger::Database::Query/row()> method.  This is equivalent to
calling L<execute()|Badger::Database::Query/execute()> and then
L<fetchrow_hashref()|DBI/fetchrow_hashref>.

    my $query = $db->query('SELECT * FROM users WHERE id=?');
    my $row   = $query->row(42);

C<Badger::Database> implements its own L<row()> and L<rows()> methods as
shortcuts to creating a query and calling the relevant method on it.

    # methods of convenience:
    $row  = $db->row('SELECT * FROM users WHERE id=?', 42)
    $rows = $db->rows('SELECT * FROM users WHERE status=?', 'active');

    # same as:
    $row  = $db->query('SELECT * FROM users WHERE id=?', 42)->row;
    $rows = $db->query('SELECT * FROM users WHERE status=?', 'active')->rows;

=head2 NAMED QUERIES

The C<Badger::Database> module allows you to define named queries.  You can
do this when the object is created, like so:

    my $db = Badger::Database->new(
        engine   => 'mysql',
        database => 'badger',
        username => 'nigel',
        password => 's3kr1t',
        queries  => {
            user_id     => 'SELECT * FROM users WHERE id=?',
            user_status => 'SELECT * FROM users WHERE status=?',
        },
    );

Or by using the L<queries()> method.

    $db->queries(
        user_id     => 'SELECT * FROM users WHERE id=?',
        user_status => 'SELECT * FROM users WHERE status=?',
    );

You can then use any of these query names in place of an explicit SQL query.

    # all-in-one execute() method
    $sth   = $db->execute( user_id => 42 );

    # all-in-one row() method
    $user  = $db->row( user_id => 42 );

    # creating an intermediate query object
    $query = $db->query('user_id');
    $row   = $query->row(42);

The benefit of this approach is that you can define your queries up front
where they're easy to maintain, instead of peppering them throughout your
source code.

=head2 QUERY TEMPLATES AND FRAGMENTS

C<Badger::Database> allows you to define query templates that are
automatically expanded upon use. For example, suppose you have two queries
that are similar, but not identical:

    $db->queries(
        user_by_name => q{
            SELECT  user.name, user.email
            FROM    user
            WHERE   name = ?
        },
        user_by_email => q{
            SELECT  user.name, user.email
            FROM    user
            WHERE   email = ?
        },
    );

C<Badger::Database> allows you to define the common part of the SQL (the
first two lines in the above queries) as a query I<fragment>.  You can define
any number of query fragments and call them whatever you like.  In this
case we'll call it C<select_user>.

    $db->fragments(
        select_user => q{
            SELECT  user.name, user.email
            FROM    user
        },
    );

To embed a fragment in a query, simple enclose the fragment name in
angle brackets, like so:

    $db->queries(
        user_by_name => q{
            <select_user>
            WHERE   name = ?
        },
        user_by_email => q{
            <select_user>
            WHERE   email = ?
        },
    );

Or with a little reformatting:

    $db->queries(
        user_by_name  => q{ <select_user> WHERE name  = ? },
        user_by_email => q{ <select_user> WHERE email = ? },
    );

Fragments can include other fragments.

    $db->fragments(
        join_order => q{
            JOIN    order
            ON      order.user_id = user.id
        },
        join_order_item => q{
            <join_order>
            JOIN    order_item
            ON      order_item.order_id = order.id
        },
        join_products => q{
            <join_order_item>
            JOIN    product
            ON      product.id = order_item.product_id
        }
        select_user_products => q{
            SELECT  DISTINCT product.*
            FROM    user
            <join_products>
        },
    );

Here are some queries using the fragments defined above.

    $db->queries(
        user_products_by_name  => q{ <select_user_products> WHERE user.name  = ? },
        user_products_by_email => q{ <select_user_products> WHERE user.email = ? },
    );

=head2 DATABASE TABLES

The all-in-one approach illustrated in the previous examples is fine for
small databases (in the sense of having few tables, rather than few records
which is largely immaterial).  However, if you have a more complex database
scheme and many different queries you want to run against it, then you will
soon find things becoming unwieldy.

TODO:
  * Badger::Database::Table allows you to compartmentalise your database
    into different tables.
  * In most cases, you'll have a 1-1 correspondence between your db tables
    and the table modules you create.  But you don't have to - a table module
    can join onto any number of different tables in the db.
  * it gets tedious writing queries by hand - B::Db::Table can automate this

=head1 METHODS

=head2 new()

Create a new database object.

    use Badger::Database;

    my $db = Badger::Database->new({
        type => 'mysql',
        name => 'badger',
        user => 'nigel',
        pass => 'top_secret',
    });

It accepts the following parameters:

=head3 type

The C<type> parameter indicates the underlying database type.

The L<Badger::Database> module is entirely generic for all database
types (Postgres, MySQL, etc.) thanks to the magic of the underlying
DBI/DBD bridge.

However, some of this generic functionality must be implemented in
different ways depending on the specific database type. An example of
this is the L<insert_id()> method which returns the identfier of the
last row inserted (used in cases where the id is automatically generated
by the underlying database).

So the C<Badger::Database> module acts as a base class for other
subclassed modules which handle the specifics of different database
types.  The C<new()> constructor method uses the C<type> parameter
to determine which of these modules should be used, loads it, and
then delegates to the C<new()> method of that subclass.

We currently have support for MySQL (L<Badger::Database::Engine::Mysql>),
Postgres (L<Badger::Database::Engine::Postgres>) and SQLite
(L<Badger::Database::Engine::SQLite>). Adding support for other databases
should be trivial as most subclasses only need to implement one or two simple
methods.

The C<type> parameter is case-insensitive and is mapped to the correct
module by a hash array defined in the C<$TYPES> package variable. For
MySQL databases, specify a C<type> of C<mysql> (or any case-insensitive
equivalent, e.g. C<MySQL>, C<mySQL>).  For PostgreSQL, we'll accept
C<pg>, C<postgres> or C<postgresql>, also case insensitive.

The object you get back will then be of the corresponding
L<Badger::Database::Engine::Mysql> subclass. In terms of their external API, they
are identical to L<Badger::Database> objects. They only differ on the
I<inside> in terms of how certain methods are implement.

The long and short of it is that you can call C<insert_id()> on either
object and it will I<Do The Right Thing> for the underlying database.

=head3 driver

If you want to connect to a database for which we don't have a subclass
module then you must manually specify the C<driver> parameter to
indicate the C<DBD> driver to use (e.g. C<mysql>, C<Pg>).

    my $db = Badger::Database->new({
        driver => 'ODBC',
        name   => 'example'
    });

In this case, some methods like C<insert_id()> may not work as expected.
If you want them to work properly then you should add them to a custom
C<Badger::Database::Engine::ODBC> subclass module (for example) and use the
C<type> parameter to use it.

=head3 name / database

The C<name> parameter specifies the database name.

    my $db = Badger::Database->new({
        type => 'mysql',
        name => 'badger',       # database name
    });

It can also be specified as C<database> in case you find that easier
to remember.

    my $db = Badger::Database->new({
        type     => 'mysql',
        database => 'badger',   # database name
    });

=head3 user / username

The C<user> (or C<username>) parameter is used to specify the username
for connecting to the database.

    my $db = Badger::Database->new({
        type => 'mysql',
        name => 'badger',       # database name
        user => 'nigel',        # user name
    });

=head3 pass / password

The C<pass> (or C<password>) parameter is used to specify the password
for connecting to the database.

    my $db = Badger::Database->new({
        type => 'mysql',
        name => 'badger',       # database name
        user => 'nigel',        # user name
        pass => 'top_secret',   # password
    });

=head2 connect()

Method to connect to the underlying database.

    $db->connect();

This can also be call as a class method to create a new database object
(via new()) and connect it.

    my $db = Badger::Database->connect({
        type => 'mysql',
        name => 'badger',
        user => 'nigel',
        pass => 'top_secret',
    });

=head2 disconnect()

Disconnect from the underlying database. This method is called
automatically by the DESTROY method when the object goes out of scope.

=head2 prepare($sql)

Method to prepares an SQL query.  It returns a C<DBI> statement handle.

    my $sth = $db->prepare('SELECT * FROM users WHERE id = ?');
    $sth->execute(12345);

=head2 query($sql, @args)

Method to prepare and execute a SQL query. It returns a C<DBI>
statement handle.  TODO: change this... it now returns a query
object.

    my $sth = $db->query('SELECT * FROM users WHERE id = ?', 12345);

=head2 row($sql, @args)

Method to return a single row from the database. It prepares and executes
an SQL query, then returns a reference to a hash array containing the
data from the first/only record returned.

    my $user = $db->row('SELECT * FROM users WHERE id = ?', 12345);
    print $user->{ name };

=head2 rows($sql, @args)

Method to return a number of rows from the database. It prepares and
executes an SQL query, then returns a reference to a list containing
references to hash arrays containing the data from the records returned.

    my $users = $db->rows('SELECT * FROM users');

    foreach my $user (@$users) {
        print $user->{ name };
    }

=head2 column($sql, @args)

Method to return a single column from the database(). It prepares and
executes a SQL query, then returns a reference to a list containing the
column value from each record returned.

    my $countries = $db->column('SELECT DISTINCT country FROM contacts');

    foreach my $country (@$countries) {
        print $country;
    }

=head2 quote($value,$data_type)

Returns a quoted version of the C<$value> string by delegation to the
DBI C<quote()> method.  An optional second parameter can be use to
specify an alternate data type.

    print $db->quote("You mustn't run with scissors");

=head2 insert_id($table,$field)

Returns the value of the identifier field of the last row inserted into
a database table.

    print "inserted realm ", $db->insert_id( customer => 'id' );

This method is redefined by subclasses to I<Do The Right Thing> for the
underlying database. See the discussion in the L<new()> method for
further details.

=head2 dbh()

Returns a reference to the underlying C<DBI> database handle.

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1999-2022 Andy Wardley.  All Rights Reserved.

This module is derived in part from the C<Template::Plugin::DBI> module,
original written by Simon Matthews and distributed as part of the
Template Toolkit.  It was re-written in 2005, adapted further for use
at Daily Internet in 2006, then again for Mobroolz in June 2007, and finally
became truly generic for Badger between July 2008 and January 2009.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Database::Table>, L<Badger::Database::Record>, L<Badger::Database::Model>,
L<Badger::Hub>

=cut

# Local Variables:
# mode: Perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
