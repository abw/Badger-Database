#============================================================= -*-perl-*-
#
# t/table/column.t
#
# Test the Badger::Database::Table column() method.
#
# Written by Andy Wardley
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Badger::Test
    debug => 'Badger::Database::Table
              Badger::Database::Queries',
    args  => \@ARGV;

use Badger::Test::Database 'TDB';

plan(9);


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
# insert some users
#-----------------------------------------------------------------------

my @data = (
    [ alice => secret  => 'Alice'   ],
    [ bob   => hidden  => 'Bob'     ],
    [ chas  => private => 'Charlie' ],
);

foreach my $row (@data) {
    my ($username, $password, $name) = @$row;
    my $user = $users->insert( 
        name     => $name,
        username => $username,
        password => $password
    );
    ok( $user, "inserted user: ". $user->id );
}

my @unames = $users->column('SELECT username FROM <table>');
is( join(', ', @unames), 'alice, bob, chas', 'got username column via query' );

my @ames = $users->column('username');
is( join(', ', @unames), 'alice, bob, chas', 'got username column via name' );

__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
