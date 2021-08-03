#============================================================= -*-perl-*-
#
# t/relation/backquote.t
#
# Test backquoting used for ordering critera,
# e.g. order by foo.bar desc, wiz.bang
#   => order by `foo`.`bar` desc, `wiz`.`bang`
#
# Written by Andy Wardley, August 2021
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Badger::Database::Relation;
use Badger::Test
    debug => 'Badger::Database::Relation',
    args  => \@ARGV,
    tests => 9;

my $relation = Badger::Database::Relation->new;
is( $relation->backquote('foo'), "`foo`", "single item: foo" );
is( $relation->backquote('foo.bar'), "`foo`.`bar`", "dotted item: foo.bar" );
is( $relation->backquote('foo.bar.baz'), "`foo`.`bar`.`baz`", "double dotted item: foo.bar.baz" );
is( $relation->backquote_order('foo'), "`foo`", "order single item: foo" );
is( $relation->backquote_order('foo.bar'), "`foo`.`bar`", "order dotted item: foo.bar" );
is( $relation->backquote_order('foo.bar.baz'), "`foo`.`bar`.`baz`", "order double dotted item: foo.bar.baz" );
is( $relation->backquote_order('foo desc'), "`foo` desc", "order single item desc: foo desc" );
is( $relation->backquote_order('foo.bar desc'), "`foo`.`bar` desc", "order dotted item desc: foo.bar desc" );
is( $relation->backquote_order('foo.bar.baz desc'), "`foo`.`bar`.`baz` desc", "order double dotted item: foo.bar.baz desc" );