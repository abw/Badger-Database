#============================================================= -*-perl-*-
#
# t/database/model.t
#
# Test the Badger::Database::Model module.
#
# Written by Andy Wardley
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Badger::Utils 'blessed';
use Badger::Test
    debug => 'Badger::Database::Model',
    args  => \@ARGV;

use Badger::Test::Database 'TDB';

plan(14);


#-----------------------------------------------------------------------
# connect to test database, clean out any old tables and create new ones
#-----------------------------------------------------------------------

my $tdb = TDB->new;
ok( $tdb->drop_test_tables, 'dropped test tables' );
ok( $tdb->create_test_tables, 'created test tables' );


#-----------------------------------------------------------------------
# fetch model and ask it for the users table
#-----------------------------------------------------------------------

my $model = $tdb->model;
ok( $model, 'got database model' );

my $users = $model->users;
ok( $users, 'got users table from users()' );           # table name
ok( blessed $users, 'got object' );
ok( $users->isa('Badger::Database::Table'), 'object isa Badger::Database::Table' );

$users = $model->users_table;
ok( $users, 'got users table from users_table()' );     # table name + _table
ok( blessed $users, 'got object again' );
ok( $users->isa('Badger::Database::Table'), 'object isa Badger::Database::Table again' );


#-----------------------------------------------------------------------
# insert a user that we can fetch out again
#-----------------------------------------------------------------------

my $user = $users->insert(
    name       => 'Tommy Testing',
    username   => 'tommy',
    password   => 'secret',
);
ok( $user, 'inserted user' );

my $uid = $user->id;
ok( $uid, "got user id: $uid" );


#-----------------------------------------------------------------------
# ask model for a user record
#-----------------------------------------------------------------------

$user = $model->users_record( id => $uid );             # table name + _record
ok( $user, 'got user from users_record()' );

$user = $model->user_record( id => $uid );              # record name + _record
ok( $user, 'got user from user_record()' );

$user = $model->user( id => $uid );                     # record name
ok( $user, 'got user from user()' );





__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
