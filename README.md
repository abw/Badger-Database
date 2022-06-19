# NAME

Badger::Database - database abstraction module

# SYNOPSIS

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

# DESCRIPTION

## INTRODUCTION

The `Badger::Database` module provides a simple, useful and moderately
powerful interface to SQL databases, implemented as a thin wrapper around the
[DBI](https://metacpan.org/pod/DBI) module and related [DBI::DBD](https://metacpan.org/pod/DBI%3A%3ADBD) modules.

It is derived from the DBI plugin module for the [Template Toolkit](https://metacpan.org/pod/Template),
originally written by Simon Matthews in 2000. I rewrote it as stand-alone
module in 2005 and started using it in a number of projects. It then proceeded
to grow in various different directions up until 2008 when I finally got a
chance to rein it it, clean it up and make it suitable for general release as
part of the [Badger](https://metacpan.org/pod/Badger) collective.

During that time there has been much activity in the Perl community and a
number of other fine database modules have sprung into existence. This begs
the question: "Why do we need another one?".

The short answer to that question is that I already had the code, was using it
regularly, found it useful and convenient, and thought other people might too.
That's not to say that there aren't more extensive and/or mature solutions out
there now that you should be using instead. `Badger::Database` is
_different_, not necessarily any _better_.

`Badger::Database` aims for convenience over complexity. It has a very
shallow learning curve that allows you to use it without having to first
master any complex concepts.  If you're already familiar with the basics
of using [DBI](https://metacpan.org/pod/DBI) then `Badger::Database` is no harder, and in some cases,
even easier.

It does not set out to be a full-blown Object/Relational Mapping tool (ORM),
nor does it go to great lengths to protect you from having to write SQL
queries. That said, it _does_ have some level of support for both of those
kinds of functionality, and more. We're happy to aim for the 80/20 sweet spot
\- if we can easily automate 80% of the more menial tasks then it leaves you
free to concentrate on the remaining 20%.

If you're looking for a full-blown ORM and don't mind a slightly steeper
learning curve then you should consider using [DBIx::Class](https://metacpan.org/pod/DBIx%3A%3AClass) or [Rose::DB](https://metacpan.org/pod/Rose%3A%3ADB)
instead. The [Fey](https://metacpan.org/pod/Fey) modules also look interesting in terms of robust SQL
generation, although I haven't had the chance to use them in anger.

`Badger::Database` currently supports MySQL, SQLite and Postgres databases.
Adding support for other database engines is a relatively simple process.

## CONNECTING TO A DATABASE

Create a new `Badger::Database` object to connect to an existing database.

    use Badger::Database;

    my $db = Badger::Database->new(
        engine   => 'mysql',
        database => 'badger',
        username => 'nigel',
        password => 's3kr1t',
    );

The `engine` parameter corresponds to a [Badger::Database::Engine](https://metacpan.org/pod/Badger%3A%3ADatabase%3A%3AEngine) module
which abstracts some of the various subtle differences between different
databases.  The `database` parameter is the name of the database.  The
optional `username` and `password` parameters can be used to supply the
relevant credentials if your database requires them.

The `Badger::Database` module will automatically connect to the database
via a [Badger::Database::Engine](https://metacpan.org/pod/Badger%3A%3ADatabase%3A%3AEngine) module.  The database will be disconnected
automatically when the `Badger::Database` object goes out of scope and is
garbage collected.

Alternately, you can provide a reference to an existing [DBI](https://metacpan.org/pod/DBI) database
handle.  In this case the database connection will not be closed
automatically when the `Badger::Database` object goes out of scope.

    my $dbh = DBI->connect(...);
    my $db  = Badger::Database(
        dbh => $dbh
    );

## RUNNING DBI QUERIES

The `Badger::Database` module provides method for making queries that
map directly onto the underlying [DBI](https://metacpan.org/pod/DBI) implementation.  You can use
the [prepare()](https://metacpan.org/pod/prepare%28%29) method to prepare a SQL query into a [DBI](https://metacpan.org/pod/DBI) statement
handle.

    my $sth = $db->prepare('SELECT * FROM users WHERE status=?');

You can then execute the query and call methods on the statement handle
as usual.

    # execute query to fetch users with 'active' status
    $sth->execute('active') || die $sth->errstr;

    # fetch row from result
    my $user = $sth->fetchrow_hashref;
    print $user->{ name };

There is also the all-in-one [execute()](https://metacpan.org/pod/execute%28%29) method.

    $sth  = $db->execute('SELECT * FROM users WHERE status=?', 'active');
    $user = $sth->fetchrow_hashref;
    print $user->{ name };

The [dbh()](https://metacpan.org/pod/dbh%28%29) method returns the current [DBI](https://metacpan.org/pod/DBI) database handle in case you
want to access any of its other methods.

    $dbh  = $db->dbh;

You'll notice that `Badger::Database` doesn't attempt to obscure the
underlying [DBI](https://metacpan.org/pod/DBI) implementation from you.  If you already know the basics
of using [DBI](https://metacpan.org/pod/DBI) then you can start using `Badger::Database` and work up
to the more advanced concepts at your own pace.

## QUERY OBJECTS

The [query()](https://metacpan.org/pod/query%28%29) method can be used to create a [Badger::Database::Query](https://metacpan.org/pod/Badger%3A%3ADatabase%3A%3AQuery)
object. This is a thin wrapper around a [DBI](https://metacpan.org/pod/DBI) statement handle, with some
extra methods of convenience.

    my $query = $db->query('SELECT * FROM users WHERE status=?');

You can call the [execute()](https://metacpan.org/pod/Badger%3A%3ADatabase%3A%3AQuery#execute) method on it,
just as you would on a naked [DBI](https://metacpan.org/pod/DBI) statement handle. In fact it returns the
[DBI](https://metacpan.org/pod/DBI) statement handle so that you can retrieve data from it.

    my $sth  = $query->execute('active');
    my $rows = $sth->fetchall_hashref;

If you want to execute a query and fetch all rows returned by it, as shown in
the example above, then you can call the
[rows()](https://metacpan.org/pod/Badger%3A%3ADatabase%3A%3AQuery#rows) method as a shortcut.

    my $query = $db->query('SELECT * FROM users WHERE status=?');
    my $rows  = $query->rows('active');

If you just want a single row then you can call the
[row()](https://metacpan.org/pod/Badger%3A%3ADatabase%3A%3AQuery#row) method.  This is equivalent to
calling [execute()](https://metacpan.org/pod/Badger%3A%3ADatabase%3A%3AQuery#execute) and then
[fetchrow\_hashref()](https://metacpan.org/pod/DBI#fetchrow_hashref).

    my $query = $db->query('SELECT * FROM users WHERE id=?');
    my $row   = $query->row(42);

`Badger::Database` implements its own [row()](https://metacpan.org/pod/row%28%29) and [rows()](https://metacpan.org/pod/rows%28%29) methods as
shortcuts to creating a query and calling the relevant method on it.

    # methods of convenience:
    $row  = $db->row('SELECT * FROM users WHERE id=?', 42)
    $rows = $db->rows('SELECT * FROM users WHERE status=?', 'active');

    # same as:
    $row  = $db->query('SELECT * FROM users WHERE id=?', 42)->row;
    $rows = $db->query('SELECT * FROM users WHERE status=?', 'active')->rows;

## NAMED QUERIES

The `Badger::Database` module allows you to define named queries.  You can
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

Or by using the [queries()](https://metacpan.org/pod/queries%28%29) method.

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

## QUERY TEMPLATES AND FRAGMENTS

`Badger::Database` allows you to define query templates that are
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

`Badger::Database` allows you to define the common part of the SQL (the
first two lines in the above queries) as a query _fragment_.  You can define
any number of query fragments and call them whatever you like.  In this
case we'll call it `select_user`.

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

## DATABASE TABLES

The all-in-one approach illustrated in the previous examples is fine for
small databases (in the sense of having few tables, rather than few records
which is largely immaterial).  However, if you have a more complex database
scheme and many different queries you want to run against it, then you will
soon find things becoming unwieldy.

TODO:
  \* Badger::Database::Table allows you to compartmentalise your database
    into different tables.
  \* In most cases, you'll have a 1-1 correspondence between your db tables
    and the table modules you create.  But you don't have to - a table module
    can join onto any number of different tables in the db.
  \* it gets tedious writing queries by hand - B::Db::Table can automate this

# METHODS

## new()

Create a new database object.

    use Badger::Database;

    my $db = Badger::Database->new({
        type => 'mysql',
        name => 'badger',
        user => 'nigel',
        pass => 'top_secret',
    });

It accepts the following parameters:

### type

The `type` parameter indicates the underlying database type.

The [Badger::Database](https://metacpan.org/pod/Badger%3A%3ADatabase) module is entirely generic for all database
types (Postgres, MySQL, etc.) thanks to the magic of the underlying
DBI/DBD bridge.

However, some of this generic functionality must be implemented in
different ways depending on the specific database type. An example of
this is the [insert\_id()](https://metacpan.org/pod/insert_id%28%29) method which returns the identfier of the
last row inserted (used in cases where the id is automatically generated
by the underlying database).

So the `Badger::Database` module acts as a base class for other
subclassed modules which handle the specifics of different database
types.  The `new()` constructor method uses the `type` parameter
to determine which of these modules should be used, loads it, and
then delegates to the `new()` method of that subclass.

We currently have support for MySQL ([Badger::Database::Engine::Mysql](https://metacpan.org/pod/Badger%3A%3ADatabase%3A%3AEngine%3A%3AMysql)),
MariaDB ([Badger::Database::Engine::MariaDB](https://metacpan.org/pod/Badger%3A%3ADatabase%3A%3AEngine%3A%3AMariaDB)),
Postgres ([Badger::Database::Engine::Postgres](https://metacpan.org/pod/Badger%3A%3ADatabase%3A%3AEngine%3A%3APostgres)) and SQLite
([Badger::Database::Engine::SQLite](https://metacpan.org/pod/Badger%3A%3ADatabase%3A%3AEngine%3A%3ASQLite)). Adding support for other databases
should be trivial as most subclasses only need to implement one or two simple
methods.

The `type` parameter is case-insensitive and is mapped to the correct
module by a hash array defined in the `$TYPES` package variable. For
MySQL databases, specify a `type` of `mysql` (or any case-insensitive
equivalent, e.g. `MySQL`, `mySQL`).  For PostgreSQL, we'll accept
`pg`, `postgres` or `postgresql`, also case insensitive.

The object you get back will then be of the corresponding
[Badger::Database::Engine::Mysql](https://metacpan.org/pod/Badger%3A%3ADatabase%3A%3AEngine%3A%3AMysql) subclass. In terms of their external API, they
are identical to [Badger::Database](https://metacpan.org/pod/Badger%3A%3ADatabase) objects. They only differ on the
_inside_ in terms of how certain methods are implement.

The long and short of it is that you can call `insert_id()` on either
object and it will _Do The Right Thing_ for the underlying database.

### driver

If you want to connect to a database for which we don't have a subclass
module then you must manually specify the `driver` parameter to
indicate the `DBD` driver to use (e.g. `mysql`, `Pg`).

    my $db = Badger::Database->new({
        driver => 'ODBC',
        name   => 'example'
    });

In this case, some methods like `insert_id()` may not work as expected.
If you want them to work properly then you should add them to a custom
`Badger::Database::Engine::ODBC` subclass module (for example) and use the
`type` parameter to use it.

### name / database

The `name` parameter specifies the database name.

    my $db = Badger::Database->new({
        type => 'mysql',
        name => 'badger',       # database name
    });

It can also be specified as `database` in case you find that easier
to remember.

    my $db = Badger::Database->new({
        type     => 'mysql',
        database => 'badger',   # database name
    });

### user / username

The `user` (or `username`) parameter is used to specify the username
for connecting to the database.

    my $db = Badger::Database->new({
        type => 'mysql',
        name => 'badger',       # database name
        user => 'nigel',        # user name
    });

### pass / password

The `pass` (or `password`) parameter is used to specify the password
for connecting to the database.

    my $db = Badger::Database->new({
        type => 'mysql',
        name => 'badger',       # database name
        user => 'nigel',        # user name
        pass => 'top_secret',   # password
    });

## connect()

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

## disconnect()

Disconnect from the underlying database. This method is called
automatically by the DESTROY method when the object goes out of scope.

## prepare($sql)

Method to prepares an SQL query.  It returns a `DBI` statement handle.

    my $sth = $db->prepare('SELECT * FROM users WHERE id = ?');
    $sth->execute(12345);

## query($sql, @args)

Method to prepare and execute a SQL query. It returns a `DBI`
statement handle.  TODO: change this... it now returns a query
object.

    my $sth = $db->query('SELECT * FROM users WHERE id = ?', 12345);

## row($sql, @args)

Method to return a single row from the database. It prepares and executes
an SQL query, then returns a reference to a hash array containing the
data from the first/only record returned.

    my $user = $db->row('SELECT * FROM users WHERE id = ?', 12345);
    print $user->{ name };

## rows($sql, @args)

Method to return a number of rows from the database. It prepares and
executes an SQL query, then returns a reference to a list containing
references to hash arrays containing the data from the records returned.

    my $users = $db->rows('SELECT * FROM users');

    foreach my $user (@$users) {
        print $user->{ name };
    }

## column($sql, @args)

Method to return a single column from the database(). It prepares and
executes a SQL query, then returns a reference to a list containing the
column value from each record returned.

    my $countries = $db->column('SELECT DISTINCT country FROM contacts');

    foreach my $country (@$countries) {
        print $country;
    }

## quote($value,$data\_type)

Returns a quoted version of the `$value` string by delegation to the
DBI `quote()` method.  An optional second parameter can be use to
specify an alternate data type.

    print $db->quote("You mustn't run with scissors");

## insert\_id($table,$field)

Returns the value of the identifier field of the last row inserted into
a database table.

    print "inserted realm ", $db->insert_id( customer => 'id' );

This method is redefined by subclasses to _Do The Right Thing_ for the
underlying database. See the discussion in the [new()](https://metacpan.org/pod/new%28%29) method for
further details.

## dbh()

Returns a reference to the underlying `DBI` database handle.

# AUTHOR

Andy Wardley [http://wardley.org/](http://wardley.org/)

# COPYRIGHT

Copyright (C) 1999-2022 Andy Wardley.  All Rights Reserved.

This module is derived in part from the `Template::Plugin::DBI` module,
original written by Simon Matthews and distributed as part of the
Template Toolkit.  It was re-written in 2005, adapted further for use
at Daily Internet in 2006, then again for Mobroolz in June 2007, and finally
became truly generic for Badger between July 2008 and January 2009.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

# SEE ALSO

[Badger::Database::Table](https://metacpan.org/pod/Badger%3A%3ADatabase%3A%3ATable), [Badger::Database::Record](https://metacpan.org/pod/Badger%3A%3ADatabase%3A%3ARecord), [Badger::Database::Model](https://metacpan.org/pod/Badger%3A%3ADatabase%3A%3AModel),
[Badger::Hub](https://metacpan.org/pod/Badger%3A%3AHub)