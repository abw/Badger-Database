#============================================================= -*-perl-*-
#
# t/database/destroy.t
#
# Test that objects get destroyed at the right time.
#
# Written by Andy Wardley
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Badger::Test
    debug => 'Badger::Database
              Badger::Database::Model
              Badger::Database::Query
              Badger::Database::Queries
              Badger::Database::Engine',
    args  => \@ARGV;

use Badger::Test::Database 'TDB';
use Badger::Test::DBConfig;

skip_all('This is a temporary test for abw');
plan(6);

my $config = {
    database => $DATABASE,
};
    
pass('calling run()');
run();
pass('called run() - all objects should be destroyed at this point');

sub run {
    my $tdb = TDB->new;
    ok( $tdb, 'connected to test database' );
#    $tdb = TDB->new;
#    ok( $tdb, 'connected to another test database' );
    my $users = $tdb->table('users');
    ok( $users, 'got users table' );
    my $query = $users->query('SELECT <columns> FROM <table>');
    ok( $query, 'got users query' );
    pass('returning from run()... expect object destruction (use -d option)');
}



__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
