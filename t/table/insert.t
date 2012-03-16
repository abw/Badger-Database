#============================================================= -*-perl-*-
#
# t/table/insert.t
#
# Test the Badger::Database::Table insert() method.
#
# Written by Andy Wardley
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
#use lib '/home/abw/projects/badger/lib';
use Badger::Test
    debug => 'Badger::Database::Table
              Badger::Database::Record-No
              Badger::Database::Queries',
    args  => \@ARGV;

use Badger::Test::Database 'TDB';

plan(10);

my $tdb = TDB->new;
ok( $tdb, 'connected to test database' );
ok( $tdb->drop_test_tables, 'dropped test tables' );
ok( $tdb->create_test_tables, 'created test tables' );

my $users = $tdb->table('users');
ok( $users, 'got users table' );

my $user = $users->insert( 
    name     => 'Andy Wardley',
    username => 'abw',
    password => 'secret',
);
ok( $user, "inserted user: ". $user->{ id } );

# check record methods
is( $user->name, 'Andy Wardley', 'name method matches' );
is( $user->username, 'abw', 'username method matches' );
is( $user->password, 'secret', 'password method matches' );

# check that any other data is forwarded to record
$user = $users->insert( 
    name     => 'Andy Wardley',
    username => 'abw',
    password => 'secret',
    answer   => 42,
);
ok( $user, "inserted user: ". $user->{ id } );
is( $user->{ answer }, 42, 'got the answer to the ultimate question' );


__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
