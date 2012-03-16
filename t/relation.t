#============================================================= -*-perl-*-
#
# t/database/relation.t
#
# Test the Badger::Database::Relation module.
#
# Written by Andy Wardley.
#
# June 2007
#
#========================================================================

use strict;
use lib qw( ./lib ../lib ../../lib );
use Badger::Test 
    tests => 1,
    debug => 'Database::Relation Database::Record';

use Badger::Database::Relation::List;

ok( 1, 'loaded list relation module' );


__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
