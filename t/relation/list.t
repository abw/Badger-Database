#============================================================= -*-perl-*-
#
# t/relation/list.t
#
# Test the one-to-many ordered list relation.
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
              Badger::Database::Relation::List',
    args  => \@ARGV;

use Badger::Test::Database 'TDB';

plan(23);


#-----------------------------------------------------------------------
# setup
#-----------------------------------------------------------------------

my $tdb = TDB->new;
ok( $tdb, 'connected to test database' );
ok( $tdb->drop_test_tables, 'dropped test tables' );
ok( $tdb->create_test_tables, 'created test tables' );


#-----------------------------------------------------------------------
# insert address, user and order
#-----------------------------------------------------------------------
my $addr = $tdb->insert_test_address;
ok( $addr, 'inserted address' );

my $user = $tdb->insert_test_user( 
    address_id => $addr->id,
);
ok( $user, "inserted user: ". $user->{ id } );

my $orders = $tdb->table('orders');
ok( $orders, 'got orders table' );

my $order = $orders->insert(
    user_id    => $user->id,
    date       => 'today',
    deliver_to => $addr->id,
);
ok( $order, 'inserted order' );



#-----------------------------------------------------------------------
# fetch items relation
#-----------------------------------------------------------------------

my $items = $order->items;
ok( $items, 'got order items' );

is( scalar(@$items), 0, 'no order items' );

my $item = $items->create( 
    product => 'widget',
    quantity => 3,
);
ok( $item, 'added order item' );
is( scalar(@$items), 1, 'one order item' );

$item = $items->create( 
    product => 'doodah',
    quantity => 5,
);
ok( $item, 'added another order item' );
is( scalar(@$items), 2, 'two order items' );

# add one to the start of the list - the rest should shuffle down
$item = $items->create( 
    product  => 'thingy',
    quantity => 7,
    line_no  => 1,
);
ok( $item, 'added yet another order item' );
is( scalar(@$items), 3, 'three order items' );


#-----------------------------------------------------------------------
# refresh order and relation
#-----------------------------------------------------------------------

$order = $orders->fetch($order->id);
ok( $order, 'refreshed order' );

$items = $order->items;
ok( $item, 'refreshed items' );

is( $items->[0]->product, 'widget', 'first item is widget' );
is( $items->[0]->line_no, 0, 'first item index 0' );

is( $items->[1]->product, 'thingy', 'second item is thingy' );
is( $items->[1]->line_no, 1, 'second item index 1' );

is( $items->[2]->product, 'doodah', 'third item is doodah' );
is( $items->[2]->line_no, 2, 'third item index 2' );




__END__
exit;

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
