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

sub test_drops {
  my $loop = IO::Async::Loop->new;
  
  my ($iterations, $timer);
  
  $timer = IO::Async::Timer::Periodic->new(
     interval => 1,
   
     on_tick => sub {
       $iterations++;
       $dtc->consume(
         sub {
           my (@data) = @_;
           diag Dumper( \@data );
           if ($iterations > 5) {
             # Stop the timer
             #$loop->remove( $timer );
             $loop->loop_stop();
             $dtc->stop();
           }
         }
       );
     },
  );
   
  $timer->start;
   
  $loop->add( $timer );
   
  $loop->run;
}

test_drops();
#stderr_like(\&test_drops,
#            qr/^\d+\s+dynamic\s+variable\s+drops/smx,
#            'errors produce messages on STDERR');

done_testing();

