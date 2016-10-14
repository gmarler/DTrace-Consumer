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

lives_ok( sub { $dtc->setopt('dynvarsize', '1k'); },
          'set dynvarsize to 1k for drop test' );


my $prog = q\
syscall:::entry
{
  self->ts = timestamp;
}

syscall:::return
/ self->ts /
{
  @c[probefunc] = avg(timestamp - self->ts);
  self->ts = 0;
}
\;

lives_ok(
  sub {
    $dtc->strcompile($prog);
  },
  'strcompile of dropping DTrace script'
);

lives_ok( sub { $dtc->go(); } );

sub test_drops {
  my $loop = IO::Async::Loop->new;
  
  my ($iterations, $timer);
  
  $timer = IO::Async::Timer::Periodic->new(
     interval => 1,
   
     on_tick => sub {
       $iterations++;
       $dtc->aggwalk(
         sub {
           my ($varid, $key, $val) = @_;
  
           if ($iterations > 3) {
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

stderr_like(\&test_drops,
            qr//,
            'drops produce messages on STDERR');

done_testing();

