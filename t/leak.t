use strict;
use warnings;

use Test::More;

use_ok( 'DTrace::Consumer' );

my $called = 0;

package My::DTrace::Consumer {
  use parent 'DTrace::Consumer';
  sub DESTROY {
    $called++;
    my $self = shift;
    $self->SUPER::DESTROY(@_);
  }
}

{
  my $libdt = My::DTrace::Consumer->new;
}

cmp_ok( $called, '==', 1, 'Destruction successful' );

done_testing();
