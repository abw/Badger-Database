#============================================================= -*-perl-*-
#
# t/database/table.t
#
# Test the Badger::Database::Table module.
#
# Written by Andy Wardley, July 2008
#
# June 2007
#
#========================================================================

use strict;
use lib qw( ./lib ../lib ../../lib );
use Badger::Test
    debug => 'Badger::Database::Table',
    args  => \@ARGV;

# TODO: we may want to skip all DB tests
use Badger::Test::Database;
use Badger::Test::Table;
use Badger::Test::DBConfig;     # imports $ENGINE, $DATABASE, $USERNAME, etc...

BEGIN {
    skip_all("You said you didn't want to run the extended tests") unless $DB_TESTS;
    plan(38);
}


my $db = Badger::Test::Database->new;
ok( $db, 'got test DB connection' );
ok( $db->drop_test_tables, 'dropped test table' );
ok( $db->create_test_tables, 'created test table' );

my $table = $db->table('users');
ok( $table, 'got users table' );

#-----------------------------------------------------------------------
# create some table subclasses
#-----------------------------------------------------------------------

package Badger::DBTest::Table0;
use base 'Badger::Database::Table';
our $TABLE = 'my_table0';

package Badger::DBTest::Table1;
use base 'Badger::Database::Table';
our $TABLE = 'my_table1';
our $ID    = 'my_id';

package Badger::DBTest::Table2;
use base 'Badger::Database::Table';
our $TABLE = 'my_table2';
our $KEY   = 'my_key';

package Badger::DBTest::Table3;
use base 'Badger::Database::Table';
our $TABLE = 'my_table3';
our $KEYS  = ['my_key1', 'my_key2'];

package Badger::Test::Table3;
use base 'Badger::Database::Table';
our $TABLE = 'baz';

package main;

# generate above class names 'coz we is lazy
my ($dbc0, $dbc1, $dbc2, $dbc3, $dbc4) = map {
    "Badger::DBTest::Table$_"
} 0..4;


#-----------------------------------------------------------------------
# these test are to ensure that the above subclasses grok their
# class variables correctly.
#-----------------------------------------------------------------------

# must always specify an engine (or a model which has a database)
my $t= $dbc1->try('new');
ok( ! $t, 'no engine should fail' );
is( $dbc1->reason, 'database.table error - No engine specified', 'got no engine error' );

$t = $dbc1->try( new => engine => 'HA HA THIS IS NOT A DATABASE' );
ok( ! $t, 'bad database should fail' );
is( $dbc1->reason, 'database.table error - Invalid engine specified: HA HA THIS IS NOT A DATABASE', 'got bad engine error' );

my $t0 = $dbc0->new( engine => $db->engine );
ok( $t0, 'got zeroth test table' );
is( $t0->engine,    $db->engine,        'zero got engine'     );
is( $t0->name,      'my_table0',        'zero got table name' );

my $t1 = $dbc1->new( engine => $db->engine );
ok( $t1, 'got first test table' );
is( $t1->engine,    $db->engine,        'one got engine'     );
is( $t1->name,      'my_table1',        'one got table name' );
is( $t1->key,       'my_id',            'one got table key'  );
is( join('+', @{ $t1->keys }),
                    'my_id',            'one got table keys' );

my $t2 = $dbc2->new( engine => $db->engine );
ok( $t2, 'got second test table' );
is( $t2->engine,    $db->engine,        'two got engine'     );
is( $t2->name,      'my_table2',        'two got table name' );
is( $t2->key,       'my_key',           'two got table key'  );
is( join('+', @{ $t2->keys }),
                    'my_key',           'two got table keys' );

my $t3 = $dbc3->new( engine => $db->engine );
ok( $t3, 'got third test table' );
is( $t3->engine,    $db->engine,        'three got engine'     );
is( $t3->name,      'my_table3',        'three got table name' );
is( join('+', @{ $t3->keys }),
                    'my_key1+my_key2',  'three got table keys' );
ok( ! $t3->try('key'),                  'three has multiple keys' );
is( $t3->reason, 'database.table error - Multiple keys are defined for the my_table3 table',
                                        'die with your boots on!' );

#-----------------------------------------------------------------------
# test via the Badger::Test::Table module
#-----------------------------------------------------------------------

my $user = $table->insert(
    username => 'nb',
    password => 'top_secret',
    name     => 'Nigel the Badger',
);
ok( $user, 'inserted user record' );
ok( $user->id, 'got user id: ' . $user->id );
is( $user->username, 'nb', 'got username' );
is( $user->password, 'top_secret', 'got passwords' );
is( $user->name, 'Nigel the Badger', 'got name' );

ok( $user->update( name => 'Franky Badger', password => 'hidden' ), 'Updated user' );
is( $user->password, 'hidden', 'set new password' );
is( $user->name, 'Franky Badger', 'set new name' );

$user = $table->fetch_one( id => $user->id );
ok( $user, 'fetched user record' );
is( $user->password, 'hidden', 'got new password' );
is( $user->name, 'Franky Badger', 'got new name' );

#print "user: ", ref($user), "\n";

__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
