#============================================================= -*-perl-*-
#
# t/relation/link.t
#
# Test the one-to-one link relation.
#
# Written by Andy Wardley
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Badger::Test
    debug => 'Badger::Database::Table
              Badger::Database::Record',
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


#-----------------------------------------------------------------------
# insert address and user
#-----------------------------------------------------------------------
my $addr = $tdb->insert_test_address;
ok( $addr, 'inserted address' );

my $user = $tdb->insert_test_user( 
    address_id => $addr->id,
);
ok( $user, "inserted user: ". $user->{ id } );


#-----------------------------------------------------------------------
# get user address_id and address
#-----------------------------------------------------------------------

is( $user->address_id, $addr->id, 'user address_id matches address.id' );
is( $user->address->id, $addr->id, 'user address id matches address.id' );
my $uaddr = $user->address;
ok( $uaddr, 'got user address' );
is( $uaddr->line1, '42 Infinity Drive', 'user address line1 matches' );





__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
