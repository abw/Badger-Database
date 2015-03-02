#============================================================= -*-perl-*-
#
# t/database/expressions.t
#
# Test the new Badger::Database::Expression module.
#
# Written by Andy Wardley.  February 2010
#
#========================================================================

use lib qw( ./lib ../lib );
use Badger::Test
    debug => 'Badger::Modules Badger::Database::Expressions Badger::Database::Expression',
    args  => \@ARGV,
    tests => 2;

use Badger::Database::Expressions;
use constant
    EXPRS => 'Badger::Database::Expressions';

pass('loaded Badger::Database::Expression');


my $exprs = EXPRS->new;
ok( $exprs, 'created expressions factory' );

my $base = $exprs->expression( database => 'DB_HANDLE' );
my $expr = $base
    ->from('users')
    ->select('id, name, email')
    ->where( id => 2 );

#print $expr->DUMP;

__END__
my $expr = $exprs->expression( from => 'users' );
ok( $expr, 'got expression' );
print "one :$expr\n";

my $two = $expr->from('blah');
ok( $two, 'got second expression' );
print "two :$two\n";

print $two->DUMP, "\n";

__END__

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
