use strict;
use warnings;
use v5.18.1;
use feature qw(say);

use Test::Most;
use Scalar::Util qw(reftype);
use Data::Dumper;

use_ok( 'Devel::libdtrace ' );


my $libdtrace = Devel::libdtrace->new();

isa_ok( $libdtrace, 'Devel::libdtrace' );
can_ok( $libdtrace, qw( setopt strcompile go aggwalk stop ) );

my $prog = "
sched:::on-cpu
{
  self->on = timestamp;
}

sched:::off-cpu
/self->on/
{
  @ = lquantize((timestamp - self->on) / 1000,
                0, 10000, 100);
}
";

diag $prog;

lives_ok(
  sub {
    $libdtrace->setopt('aggrate','10ms');
  },
  'setopt of aggrate to 10ms successful'
);

lives_ok(
  sub {
    $libdtrace->strcompile($prog);
  },
  'strcompile of sched program'
);

lives_ok(
  sub {
    $libdtrace->go();
  },
  'Run go() on sched program'
);

lives_ok(
  sub {
    $libdtrace->aggwalk(
      sub {
        diag Data::Dumper::Dumper( \@_ );
        my ($varid, $key, $val) = @_;

        
      }
    );
  },
  'walking sched agg shows correct data'
);

done_testing();
