#============================================================= -*-perl-*-
#
# t/database/tables.t
#
# Test the Badger::Database module in its ability to create table objects
#
# Written by Andy Wardley
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Badger::Test
    debug => 'Badger::Database::Table
              Badger::Database::Engine',
    args  => \@ARGV;

use Badger::Test::Database 'TDB';

plan(43);


#-----------------------------------------------------------------------
# connect to test database, clean out any old tables and create new ones
#-----------------------------------------------------------------------

my $tdb = TDB->new;
ok( $tdb, 'connected to test database' );
ok( $tdb->drop_test_tables, 'dropped test tables' );
ok( $tdb->create_test_tables, 'created test tables' );


#-----------------------------------------------------------------------
# should be able to access table objects defined in database subclass
#-----------------------------------------------------------------------

my $users = $tdb->table('users');
ok( $users, 'got users table' );
my $user = $users->insert(
    name       => 'Arthur Dent',
    username   => 'dent',
    password   => 'secret',
);
ok( $user, 'inserted user' );
ok( $user->id, 'got user id: ' . $user->id );


#-----------------------------------------------------------------------
# create another database obejct, adding extra tables and queries
#-----------------------------------------------------------------------

$tdb = TDB->new(
    queries => {
        user_by_name => 'SELECT * FROM badger_test_users WHERE name=?',
    },
    tables => {
        sessions => {
            table   => 'badger_test_sessions',
            serial  => 'id',
            fields  => 'data status',
            queries => {
                expire  => "UPDATE <table> SET status='expired' WHERE <keys=?>",
                active  => "SELECT <fields> FROM <table> WHERE status='active'",
                expired => "SELECT <fields> FROM <table> WHERE status='expired'",
            },
        },
    },
);
ok( $tdb, 'connected to test database with custom table' );


#-----------------------------------------------------------------------
# clean out any old tables and create new ones - this also checks
# that the $QUERIES defined for the database are active
#-----------------------------------------------------------------------

ok( $tdb->drop_test_tables, 'dropped test tables' );
ok( $tdb->create_test_tables, 'created test tables' );


#-----------------------------------------------------------------------
# fetch the users tables - this is defined in the $TABLES pkg var.
# check we can do some of the queries that are defined for it
#-----------------------------------------------------------------------

$users = $tdb->table('users');
ok( $users, 'got users table' );

ok( $users->do( insert => 'abw', 'secret', 'Andy Wardley', 0 ),
    'inserted user' );
my $uid = $users->insert_id;
ok( $uid, "got inserted user id: $uid" );

$user = $users->row( by_id => $uid );
ok( $user, 'got user row' );

is( $user->{ username }, 'abw', 'username matches' );
is( $user->{ password }, 'secret', 'password matches' );
is( $user->{ name }, 'Andy Wardley', 'name matches' );


#-----------------------------------------------------------------------
# check that we can use the extra database queries we provided above in 
# the configuration, and also define other queries via queries()
#-----------------------------------------------------------------------

$user = $tdb->row( user_by_name => 'Andy Wardley' );
ok( $user, 'got user row by name' );
is( $user->{ id }, $uid, 'user id matches' );

ok( 
    $tdb->queries( 
        user_by_username => 'SELECT * FROM badger_test_users WHERE username=?',
        user_by_id       => 'SELECT * FROM badger_test_users WHERE id=?',
    ),
    'added query to database'
);

$user = $tdb->row( user_by_username => 'abw' );
ok( $user, 'got user row by username' );
is( $user->{ id }, $uid, 'user id matches again' );

$user = $tdb->row( user_by_id => $user->{ id } );
ok( $user, 'got user row by id' );
is( $user->{ name }, 'Andy Wardley', 'user name matches this time' );


#-----------------------------------------------------------------------
# should also be able to add queries to a table
#-----------------------------------------------------------------------

ok( 
    $users->queries( 
        username => 'SELECT <columns> FROM <table> WHERE username=?',
    ),
    'added query to users table'
);

$user = $users->row( username => 'abw' );
ok( $user, 'got user row from table by username' );
is( $user->{ id }, $uid, 'user id matches yet again' );

my $user_by_username = $users->query('username');
$user = $user_by_username->row('abw');
ok( $user, 'got user row from table by username query' );
is( $user->{ id }, $uid, 'user id matches, yippee!' );


#-----------------------------------------------------------------------
# now check that we can get the sessions table we defined above
#-----------------------------------------------------------------------

my $sessions = $tdb->table('sessions');
ok( $sessions, 'got sessions table' );

my $session = $sessions->insert( data => 'Hello World', status => 'active' );
ok( $session, 'inserted session: ' . $session->id );

$session = $sessions->insert( data => 'Goodbye World', status => 'expired' );
ok( $session, 'inserted expired session: ' . $session->id );

$session = $sessions->insert( data => 'Hello Badger', status => 'active' );
ok( $session, 'inserted session to switch: ' . $session->id );


#-----------------------------------------------------------------------
# we should be able to use the named queries defined with it
#-----------------------------------------------------------------------

# all-in-one
my $active = $sessions->rows('active');

is( scalar(@$active), 2, 'got two active sessions' );
is( $active->[0]->{ data }, 'Hello World', 'got first active session data' );
is( $active->[1]->{ data }, 'Hello Badger', 'got second active session data' );

# create query object, then call rows
my $expired_query = $sessions->query('expired');
my $expired = $expired_query->rows;

is( scalar(@$expired), 1, 'got one expired session' );
is( $expired->[0]->{ data }, 'Goodbye World', 'got only expired session data' );


#-----------------------------------------------------------------------
# expire a query
#-----------------------------------------------------------------------

ok( $sessions->do( expire => $session->{id} ), 'expired session' );

# all-in-one again
$active = $sessions->rows('active');

is( scalar(@$active), 1, 'got one active session' );
is( $active->[0]->{ data }, 'Hello World', 'got only active session data' );

# reuse query object created above
$expired = $expired_query->rows;

is( scalar(@$expired), 2, 'got two expired sessions' );
is( $expired->[0]->{ data }, 'Goodbye World', 'got first expired session data' );
is( $expired->[1]->{ data }, 'Hello Badger', 'got second expired session data' );





__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
