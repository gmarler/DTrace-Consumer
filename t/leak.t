use strict;
use warnings;

use Test::More;

use_ok( 'Devel::libdtrace ' );

my $called = 0;

package My::Devel::libdtrace {
  use parent 'Devel::libdtrace';
  sub DESTROY {
    $called++;
    my $self = shift;
    $self->SUPER::DESTROY(@_);
  }
}

{
  my $libdt = My::Devel::libdtrace->new;
}

cmp_ok( $called, '==', 1, 'Destruction successful' );

done_testing();
