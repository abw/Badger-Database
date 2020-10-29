#============================================================= -*-perl-*-
#
# t/relation/many_link.t
#
# Test the one-to-many relation via an intermediate link table.
#
# Written by Andy Wardley, October 2020
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

plan(8);

#-----------------------------------------------------------------------
# setup
#-----------------------------------------------------------------------

my $tdb = TDB->new;
ok( $tdb, 'connected to test database' );
ok( $tdb->drop_test_tables, 'dropped test tables' );
ok( $tdb->create_test_tables, 'created test tables' );

#-----------------------------------------------------------------------
# insert user
#-----------------------------------------------------------------------
my $user = $tdb->insert_test_user;
ok( $user, "inserted user: ". $user->{ id } );

my $addr = $tdb->insert_test_address;
ok( $addr, "inserted address: ". $addr->{ id } );

#-----------------------------------------------------------------------
# insert an order with some items
#-----------------------------------------------------------------------
my $order = $user->orders->insert(
    user_id    => $user->id,
    date       => 'yesterday',
    deliver_to => $addr->id,
);
ok( $order, 'inserted order' );

$order->items->create(
    product => 'widget',
    quantity => 1,
);
$order->items->create(
    product => 'doodah',
    quantity => 2,
);
$order->items->create(
    product => 'doodah',
    quantity => 3,
);
my $items = $order->items;
ok( $items, 'got order items' );
my $n_items = scalar @$items;
is( $n_items, 3, 'three items in order' );

#-----------------------------------------------------------------------
# fetch the user's order_items via the link relation
#-----------------------------------------------------------------------
__END__

$items = $user->order_items;
ok( $items, "fetched order items from user");
$n_items = scalar @$items;
is( $n_items, 3, 'three order items' );

print TDB->dump_data($items );




# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
