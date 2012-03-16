#============================================================= -*-perl-*-
#
# t/database/database.t
#
# Test the Badger::Database module.
#
# Written by Andy Wardley
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Badger::Test
    debug => 'Badger::Database
              Badger::Test::DBConfig',
    args  => \@ARGV;

use Badger::Test::Database 'TDB';

plan(34);


#-----------------------------------------------------------------------
# connect to test database, clean out any old tables and create new ones
#-----------------------------------------------------------------------

my $tdb = TDB->new( options => { PrintError => 1 } );
ok( $tdb, 'connected to test database' );
ok( $tdb->database, 'got database: ' . $tdb->database );
ok( $tdb->name, 'got database name: ' . $tdb->name );

ok( $tdb->drop_test_tables, 'dropped test tables' );
ok( $tdb->create_test_tables, 'created test tables' );


#-----------------------------------------------------------------------
# test prepare() method which returns a regular DBI statement handle
#-----------------------------------------------------------------------

my @ids;
my $sth = $tdb->prepare(
    'INSERT INTO badger_test_users (name,username,password) VALUES (?,?,?)'
);
ok( $sth, 'created INSERT sth' );

ok( 
    $sth->execute('Ford Prefect', 'ford', 'b3t3lg3us3'), 
    'added Ford Prefect' 
);
push(@ids, $tdb->insert_id('badger_test_users', 'id'));

ok( 
    $sth->execute('Tricia McMillan', 'trillian', '2677091'), 
    'added Trillian' 
);
push(@ids, $tdb->insert_id('badger_test_users', 'id'));


#-----------------------------------------------------------------------
# test all-in-one execute() method
#-----------------------------------------------------------------------

my $id = $ids[-1];
ok( $id, "Got insert id: $id" );

$sth = $tdb->execute("SELECT * FROM badger_test_users WHERE id=?", $id);
ok( $sth, 'Got statement handle from select' );
my $user = $sth->fetchrow_hashref;
ok( $user, 'Got user record' );
is( $user->{ name     }, 'Tricia McMillan',     "Got Trillian's name" );
is( $user->{ username }, 'trillian',            "Got Trillian's username" );
is( $user->{ password }, '2677091',             "Got Trillian's password" );


#-----------------------------------------------------------------------
# test row() method
#-----------------------------------------------------------------------

$user = $tdb->row("SELECT * FROM badger_test_users WHERE id=?", $id);
ok( $user, 'Got user row' );
is( $user->{ name }, 'Tricia McMillan', "Got Trillian's name again" );


#-----------------------------------------------------------------------
# test rows() methods
#-----------------------------------------------------------------------

my $users = $tdb->rows('SELECT * FROM badger_test_users');
is( scalar(@$users), 2, 'got two users' );
is( $users->[0]->{ name }, 'Ford Prefect',      "Got Ford as first user" );
is( $users->[1]->{ name }, 'Tricia McMillan',   "Got Trillian as second user" );


#-----------------------------------------------------------------------
# test query() method to create query object
#-----------------------------------------------------------------------

my $user_by_id = $tdb->query('SELECT * FROM badger_test_users WHERE id=?');
    
$user = $user_by_id->row($ids[0]);
is( $user->{ name }, 'Ford Prefect', "Got Ford as first query" );

$user = $user_by_id->row($ids[1]);
is( $user->{ name }, 'Tricia McMillan', "Got Trillian as second query" );


#-----------------------------------------------------------------------
# another query to select all so we can use rows()
#-----------------------------------------------------------------------

my $all_users = $tdb->query('SELECT * FROM badger_test_users');
    
$users = $all_users->rows();
is( $users->[0]->{ name }, 'Ford Prefect',      "Got Ford again" );
is( $users->[1]->{ name }, 'Tricia McMillan',   "Got Trillian again" );


#-----------------------------------------------------------------------
# create another database obejct, adding some extra queries (TODO: and tables)
#-----------------------------------------------------------------------

$tdb = TDB->new(
    queries => {
        user_by_name => 'SELECT * FROM badger_test_users WHERE name=?',
    },
);
ok( $tdb, 'connected to test database' );


#-----------------------------------------------------------------------
# check that we can use the extra database queries we provided above in 
# the configuration, and also define other queries via queries()
#-----------------------------------------------------------------------

$user = $tdb->row( user_by_name => 'Tricia McMillan' );
ok( $user, 'got user row by name' );
is( $user->{ id }, $id, 'user id matches' );

ok( 
    $tdb->queries( 
        user_by_username => 'SELECT * FROM badger_test_users WHERE username=?',
        user_by_id       => 'SELECT * FROM badger_test_users WHERE id=?',
    ),
    'added query to database'
);

$user = $tdb->row( user_by_username => 'trillian' );
ok( $user, 'got user row by username' );
is( $user->{ id }, $id, 'user id matches again' );

$user = $tdb->row( user_by_id => $user->{ id } );
ok( $user, 'got user row by id' );
is( $user->{ name }, 'Tricia McMillan', 'user name matches this time' );


#-----------------------------------------------------------------------
# we should be able to create a new database from an existing $dbh
#-----------------------------------------------------------------------

my $tdb2 = Badger::Database->new( dbh => $tdb->dbh );
ok( $tdb, 'created new database from dbh' );
$user = $tdb->row('SELECT * FROM badger_test_users WHERE id=?', $id);
ok( $user, 'got user from new database' );
is( $user->{ name }, 'Tricia McMillan', 'user name matches again' );

# call explicit disconnect
$tdb2->disconnect;


__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
