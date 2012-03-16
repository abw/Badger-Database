#============================================================= -*-perl-*-
#
# t/table/update.t
#
# Test the Badger::Database::Table update() method.
#
# Written by Andy Wardley
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Badger::Test
    debug => 'Badger::Database::Table
              Badger::Database::Record
              Badger::Database::Queries',
    args  => \@ARGV;

use Badger::Test::Database 'TDB';

plan(20);


#-----------------------------------------------------------------------
# setup
#-----------------------------------------------------------------------

my $tdb = TDB->new;
ok( $tdb, 'connected to test database' );
ok( $tdb->drop_test_tables, 'dropped test tables' );
ok( $tdb->create_test_tables, 'created test tables' );

my $users = $tdb->table('users');
ok( $users, 'got users table' );


#-----------------------------------------------------------------------
# insert user record
#-----------------------------------------------------------------------

my $user = $users->insert( 
    name     => 'Andy Wardley',
    username => 'abw',
    password => 'secret',
);
ok( $user, "inserted user: ". $user->{ id } );
is( $user->name, 'Andy Wardley', 'name method matches' );
is( $user->username, 'abw', 'username method matches' );
is( $user->password, 'secret', 'password method matches' );


#-----------------------------------------------------------------------
# update via table
#-----------------------------------------------------------------------

ok( $users->update( id => $user->id, password => 'hidden' ), 'updated password via table' );

$user = $users->fetch( $user->id );
ok( $user, 'fetched user back out of the database' );
is( $user->password, 'hidden', 'new password was saved' );


#-----------------------------------------------------------------------
# update via record
#-----------------------------------------------------------------------

is( $user->password('private'), 'private', 'updated password via record' );
is( $user->password, 'private', 'record returns new password' );

$user = $users->fetch( $user->id );
ok( $user, 'fetched user back out of the database again' );
is( $user->password, 'private', 'new password was saved again' );


#-----------------------------------------------------------------------
# should not be able to update username field or other fields that 
# don't exist
#-----------------------------------------------------------------------

ok( ! $user->try( update => username => 'fred' ), 'did not update username' );
like( $user->reason, qr/No valid fields were specified to update/, 'got no valid fields error' );
is( $user->username, 'abw', 'username unchanged' );

ok( ! $user->try( update => another => 'thing' ), 'did not update another thing' );
like( $user->reason, qr/No valid fields were specified to update/, 'got no valid fields error again' );



__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
