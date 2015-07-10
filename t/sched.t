use strict;
use warnings;
use v5.18.1;
use feature qw(say);

use Test::Most;
use Scalar::Util qw(reftype);
use Data::Dumper;

use_ok( 'DTrace::Consumer' );


my $dtc = DTrace::Consumer->new();

isa_ok( $dtc, 'DTrace::Consumer' );
can_ok( $dtc, qw( setopt strcompile go aggwalk stop ) );

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
    $dtc->setopt('aggrate','10ms');
  },
  'setopt of aggrate to 10ms successful'
);

lives_ok(
  sub {
    $dtc->strcompile($prog);
  },
  'strcompile of sched program'
);

lives_ok(
  sub {
    $dtc->go();
  },
  'Run go() on sched program'
);

lives_ok(
  sub {
    $dtc->aggwalk(
      sub {
        diag Data::Dumper::Dumper( \@_ );
        my ($varid, $key, $val) = @_;

        
      }
    );
  },
  'walking sched agg shows correct data'
);

done_testing();
