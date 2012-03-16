#========================================================================
#
# Badger::Database::Engines
#
# DESCRIPTION
#   Factory module for locating, loading and instantiating database
#   engine objects.
#
# AUTHOR
#   Andy Wardley   <abw@wardley.org>
#
#========================================================================

package Badger::Database::Engines;

use Badger::Factory::Class
    version => 0.01,
    debug   => 0,
    item    => 'engine',
    path    => 'Badger::Database::Engine BadgerX::Database::Engine',
    words   => 'HASH',
    engines => {
        # alternate names/cases 
        pg     => 'Badger::Database::Engine::Postgres',
        sqlite => 'Badger::Database::Engine::SQLite',
    };

    
sub type_args {
    my $self = shift;
    my $type = shift;
    my $args = @_ == 1 ? shift : { @_ };

    # single scalar value is assumed to be database name
    $args = { database => $args }
        unless ref $args eq HASH;
    
    return ($type, $args);
}


1;

=head1 NAME

Badger::Database::Engines - factory module for database engines

=head1 SYNOPSIS

    use Badger::Database::Engines;

    my $engine = Engines->engine( 
        mysql => {
            database => 'test',
            username => 'test',
            password => 'test',
        },
    );

    my $sth = $engine->query('SELECT * FROM users WHERE id=?', 42);

=head1 DESCRIPTION

This module is a factory for creating L<Badger::Database::Engine> objects.
It is a subclass of L<Badger::Factory> which implements most of the 
functionality required to locate, load and instantiate database engines.

The L<engine()> method will locate, load and instantiate a database engine
object from the arguments passed to it.  You can call it as a class method
like so:

    my $engine = Badger::Database::Engines->engine(
        mysql => {
            database => 'testdb',
            username => 'tester',
            password => 's3kr1t',
        }
    );

Or you can create a C<Badger::Database::Engines> object first if you prefer.
The end result is the same.

    my $engines = Badger::Database::Engines->new;
    my $engine  = $engines->engine(
        mysql => {
            database => 'testdb',
            username => 'tester',
            password => 's3kr1t',
        }
    );

=head1 METHODS

=head2 new(\%config)

Constructor method inherited from L<Badger::Factory> which is used to create a
new L<Badger::Database::Engines> object.

    my $engines = Badger::Database::Engines->new;

You can specify any additional engine mappings using the L<engines> 
parameter.    

    my $engines = Badger::Database::Engines->new(
        engines => {
            mysql => 'Another::Mysql::Engine',
            odbc  => 'BadgerX::Database::Engine::ODBC',     # does not exist
        },
    );

=head2 engine($type,@args)

This method is used to locate, load and instantiate a database engine object.
It is an alias to the L<item()|Badger::Factory/item()> method inherited from
L<Badger::Factory>.

The first argument is the database engine type, corresponding to one of the
L<Badger::Database::Engine::*|Badger::Database::Engine> modules.
The remaining arguments are the connection parameters for the database.

    my $engine = $engines->engine(
        mysql => {
            database => 'testdb',
            username => 'tester',
            password => 's3kr1t',
        }
    );

The engine type can be specified in lower case (e.g. C<mysql>, C<postgres>,
C<sqlite>) or using the correct capitalisation for the engine module (e.g.
C<Mysql>, C<Postgres>, C<SQLite>). We also support C<pg> as an alias for
C<postgres>.

If a single non-reference value follows the database type then it is assumed
to be the database name and is coerced to a hash reference.

    # this is syntactic sugar...
    my $engine = $engines->engine(
        mysql => 'testdb'
    );
    
    # ...for this
    my $engine = $engines->engine(
        mysql => {
            database => 'testdb',
        },
    );

=head2 engines()

This method provides access to the engine lookup table.
It is an alias to the L<item()|Badger::Factory/items()> method inherited from
L<Badger::Factory>.

=head1 INTERNAL METHODS

=head2 type_args(@args)

This methods redefines the L<type_args()|Badger::Factory/type_args()> method
inherited from L<Badger::Factory>.  It implements the magic that allows you
to specify the database connection parameters as a single string (the database
name) which it coerces to a hash reference.

    # this is syntactic sugar...
    my $engine = $engines->engine( 
        mysql => 'testdb' 
    );
    
    # ...for this
    my $engine = $engines->engine( 
        mysql => { 
            database => 'testdb' 
        } 
    );

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 2005-2009 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Badger::Database>, 
L<Badger::Database::Engine>, 
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
