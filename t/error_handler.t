use strict;
use warnings;
use v5.18.1;
use feature qw(say);

use Test::Most;
use Data::Dumper;
use IO::Async::Timer::Periodic;
use IO::Async::Loop;
use Test::Output;


use_ok( 'DTrace::Consumer' );

my $dtc = DTrace::Consumer->new();

isa_ok( $dtc, 'DTrace::Consumer' );
can_ok( $dtc, qw( strcompile setopt go consume stop ) );

my $prog = q\
BEGIN {
  x = (int *)NULL;
  y = *x;
  trace(y);
  trace(strlen(0));
}

syscall:::entry
{
  @c[probefunc] = count();
}
\;

lives_ok(
  sub {
    $dtc->strcompile($prog);
  },
  'strcompile of erroring DTrace script'
);

lives_ok( sub { $dtc->go(); },
          'engage the DTrace probes that will generate an error');

sub test_error {
  # We need to fail immediately in the consume, otherwise it'll never exit on its own
  $dtc->consume(
    sub {
      diag("WAKA WAKA");
      fail("Run long enough to generate an error"); 
    }
  );
}

stderr_like(\&test_error,
            qr/^error\s+on\s+enabled\s+probe\s+ID/smx,
            'errors produce messages on STDERR');

done_testing();

