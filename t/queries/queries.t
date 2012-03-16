#============================================================= -*-perl-*-
#
# t/queries/queries.t
#
# Test the Badger::Database::Queries module.
#
# Written by Andy Wardley
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
#use lib '/home/abw/projects/badger/lib';
use Badger::Test
    tests => 7,
    debug => 'Badger::Database::Queries Badger::Factory',
    args  => \@ARGV;

use Badger::Test::Database 'TDB';

my $db = TDB->new( 
    queries => {
        get_user => 'SELECT * FROM users WHERE id=?',
    },
    query_path => 'Badger::Test::Query',
);


#-----------------------------------------------------------------------
# should be able to fetch a raw SQL query...
#-----------------------------------------------------------------------

my $query = $db->query('SELECT * FROM users');
ok( $query, 'got raw SQL query' );
is( $query->sql, 'SELECT * FROM users', 'got raw sql' );


#-----------------------------------------------------------------------
# ...or a named query...
#-----------------------------------------------------------------------

$query = $db->query('get_user');
ok( $query, 'got named SQL query' );
is( $query->sql, 'SELECT * FROM users WHERE id=?', 'got named sql' );


#-----------------------------------------------------------------------
# ...or a query module...
#-----------------------------------------------------------------------

$query = $db->query('friends');
ok( $query, 'got friends query module' );
is( $query->sql, 'SELECT * FROM friends WHERE friend_id=?', 'got friends sql' );

$query = $db->query('select');
ok( $query, 'got select query module' );


