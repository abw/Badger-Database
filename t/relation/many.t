#============================================================= -*-perl-*-
#
# t/relation/many.t
#
# Test the one-to-many relation.
#
# Written by Andy Wardley
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Badger::Test
    debug => 'Badger::Database::Table
              Badger::Database::Record
              Badger::Database::Relation
              Badger::Database::Relation::Many',
    args  => \@ARGV;

use Badger::Test::Database 'TDB';

plan(19);


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
# insert orders
#-----------------------------------------------------------------------

my $orders = $tdb->table('orders');
ok( $orders, 'got orders table' );

my $order1 = $orders->insert(
    user_id    => $user->id,
    date       => 'yesterday',
    deliver_to => $addr->id,
);
ok( $order1, 'inserted first order' );

my $order2 = $orders->insert(
    user_id    => $user->id,
    date       => 'today',
    deliver_to => $addr->id,
);
ok( $order2, 'inserted second order' );

my $order3 = $orders->insert(
    user_id    => $user->id,
    date       => 'tomorrow',
    deliver_to => $addr->id,
);
ok( $order1, 'inserted third order' );


#-----------------------------------------------------------------------
# fetch orders relation
#-----------------------------------------------------------------------

my $uorders = $user->orders;
ok( $uorders, 'got user orders' );

is( scalar(@$uorders), 3, 'three orders' );
is( $uorders->[0]->id, $order1->id, 'first order id' );
is( $uorders->[1]->id, $order2->id, 'second order id' );
is( $uorders->[2]->id, $order3->id, 'third order id' );



#-----------------------------------------------------------------------
# create new order
#-----------------------------------------------------------------------

my $order4 = $uorders->create(
    date       => 'next week',
    deliver_to => $addr->id,
);
ok( $order4, 'added new order' );
is( $order4->user_id, $user->id, 'order has user id set' );
is( $order4->user->id, $user->id, 'order has user available' );

$uorders->fetch;

is( scalar(@$uorders), 4, 'now four orders' );
is( $uorders->[3]->id, $order4->id, 'fourth order id' );




__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
