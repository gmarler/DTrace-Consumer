use strict;
use warnings;

use Test::More;

use Devel::libdtrace;

my $called = 0;

package Devel::libdtrace {
  sub DESTROY { $called++ }
}

{ my $libdt = Devel::libdtrace->new }
cmp_ok( $called, '==', 1, 'Destruction successful' );

done_testing();
