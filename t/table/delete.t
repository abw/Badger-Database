#============================================================= -*-perl-*-
#
# t/table/delete.t
#
# Test the Badger::Database::Table delete() method.
#
# Written by Andy Wardley
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use lib '/home/abw/projects/badger/lib';
use Badger::Test
    debug => 'Badger::Database::Table
              Badger::Database::Record
              Badger::Database::Queries',
    args  => \@ARGV;

use Badger::Test::Database 'TDB';

plan(19);


#-----------------------------------------------------------------------
# setup
#-----------------------------------------------------------------------

my $tdb = TDB->new;
ok( $tdb, 'connected to test database' );
ok( $tdb->drop_test_tables, 'dropped test tables' );
ok( $tdb->create_test_tables, 'created test tables' );

my $users = $tdb->table('users');
ok( $users, 'got users table' );

my $user;


#-----------------------------------------------------------------------
# insert user record
#-----------------------------------------------------------------------

sub add_user {
    my $user = $users->insert( 
        name     => 'Andy Wardley',
        username => 'abw',
        password => 'secret',
    );
    ok( $user, "inserted user: ". $user->{ id } );
}


#-----------------------------------------------------------------------
# delete via table
#-----------------------------------------------------------------------

$user = add_user;
ok( $user, 'added user' );
ok( $users->delete( $user->id ), 'deleted user with positional arg' );
ok( ! $users->fetch( $user->id ), 'user ' . $user->id . ' deleted from database' );

$user = add_user;
ok( $user, 'added user again' );
ok( $users->delete( id => $user->id ), 'deleted user with named param' );
ok( ! $users->fetch( $user->id ), 'user ' . $user->id . ' deleted from database' );


#-----------------------------------------------------------------------
# delete via record
#-----------------------------------------------------------------------

$user = add_user;
ok( $user->delete, 'deleted user via record method' );
ok( ! $users->fetch( $user->id ), 'user ' . $user->id . ' deleted from database' );



#-----------------------------------------------------------------------
# check delete() checks for valid keys 
#-----------------------------------------------------------------------

$user = add_user;
ok( ! $users->try( delete => username => 'abw' ), 'did not delete by username' );
like( $users->reason, qr/No 'id' parameter specified to delete/, 'got no id parameter error' );
$user = $users->fetch( $user->id );
ok( $user, 'user ' . $user->id . ' not deleted' );



__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
