#============================================================= -*-perl-*-
#
# t/queries/select.t
#
# Test the Badger::Database::Query::Select module.
#
# Written by Andy Wardley
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Badger::Test
    debug => 'Badger::Database::Query Badger::Database::Query::Select',
    args  => \@ARGV;

use Badger::Test::Database 'TDB';
use Badger::Test::DBConfig;     # imports $ENGINE, $DATABASE, $USERNAME, etc...

BEGIN {
    skip_all("You said you didn't want to run the extended tests") unless $DB_TESTS;
    plan(7);
}

my $select = TDB->query('select');
ok( $select, 'got select query module' );

$select
    ->table('users')
    ->columns('name, email')
    ->where('id=?')
    ->columns('age')
    ->order_by('age');

is(
    $select->sql,
    'SELECT name, email, age FROM users WHERE id=? ORDER BY age',
    'got generated SQL for database query'
);

#-----------------------------------------------------------------------
# generate select query via select() method
#-----------------------------------------------------------------------

my $users = TDB->table('users');
ok( $users, 'got users table' );
my $query = $users->select('id, name')->where('id=100');
ok( $query, 'got select query' );
is(
    $query->sql,
    # note we get the *correct* table name because the query was generated
    # by the table object which knows its own name
    'SELECT id, name FROM badger_test_users WHERE id=100',
    'got generated SQL for table query'
);

#-----------------------------------------------------------------------
# more SQL generation tests
#-----------------------------------------------------------------------

is(
    $users->select( 'id, name' )
        ->table('orders')
        ->columns('orders.total')
        ->where('orders.id=?')
        ->where('users.id=?')
        ->sql,
    'SELECT id, name, orders.total FROM badger_test_users, orders WHERE orders.id=? AND users.id=?',
    'got generated SQL for query with multiple where() clauses'
);

is(
    $users->select('id')
        ->join('JOIN orders ON blah')
        ->where('orders.id=?')
        ->sql,
    'SELECT id FROM badger_test_users JOIN orders ON blah WHERE orders.id=?',
    'got generated SQL for query with join'
);

# This functionality has been removed.  It's probably not required but it
# might return in a different guise at some point in the future.

#is(
#    $users->select('id,name')
#        ->where('id=?')
#        ->or
#        ->where('name=?')
#        ->sql,
#    'SELECT id,name FROM badger_test_users WHERE id=? OR name=?',
#    'got generated SQL for query with or clauses'
#);
#
#is(
#    $users->select('id,name')
#        ->or('id=?', 'name=?')
#        ->sql,
#    'SELECT id,name FROM badger_test_users WHERE id=? OR name=?',
#    'got generated SQL for another query with or clauses'
#);
