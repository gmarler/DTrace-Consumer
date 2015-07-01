use strict;
use warnings;
use v5.18.1;
use feature qw(say);

use Test::Most;
use Data::Dumper;
use IO::Async::Timer::Periodic;
use IO::Async::Loop;


use_ok( 'Devel::libdtrace ' );

my $libdtrace = Devel::libdtrace->new();

isa_ok( $libdtrace, 'Devel::libdtrace' );
can_ok( $libdtrace, qw( strcompile setopt go consume stop ) );

dies_ok( sub { $libdtrace->strcompile(); } );
throws_ok( sub { $libdtrace->strcompile(61707); },
           qr/Program\smust\sbe\sa\sstring/,
           'strcompile with an integer, rather than a string' );
dies_ok( sub { $libdtrace->strcompile('this is not D'); },
         'strcompile of non-D script should die' );
dies_ok( sub { $libdtrace->strcompile('bogus-probe { trace(0); }'); },
         'strcompile of bogus probe should die' );

# TODO: Test output of this
lives_ok( sub { $libdtrace->strcompile('BEGIN { trace(9904); }'); },
          'strcompile of valid BEGIN clause should live' );

dies_ok( sub { $libdtrace->setopt(); },
         'setopt() with no args should die' );
dies_ok( sub { $libdtrace->setopt('bogusoption'); },
         'setopt() with bogus option should die' );
dies_ok( sub { $libdtrace->setopt('bufpolicy'); },
         'setopt() of option needing value (but has none) should die' );
dies_ok( sub { $libdtrace->setopt('bufpolicy', 100); },
         'setopt() of option with int (rather than string) value should die' );

lives_ok( sub { $libdtrace->setopt('bufpolicy', 'ring'); },
          'set bufpolicy of "ring"');
lives_ok( sub { $libdtrace->setopt('bufpolicy', 'switch'); },
          'set bufpolicy of "switch"');

lives_ok( sub { $libdtrace->go(); } );

my ($seen, $lastrec);

lives_ok(
  sub {
    $libdtrace->consume(
      sub {
        my $probe = shift;
        my $rec   = shift;
        say "PROBE PROVIDER: [" . $probe->{provider} . "]";
        say "  PROBE MODULE: [" . $probe->{module} . "]";
        say "PROBE FUNCTION: [" . $probe->{function} . "]";
        say "    PROBE NAME: [" . $probe->{name} . "]";

        if (!$rec) {
          cmp_ok($seen, '==', 1, 'Data was seen');
          $lastrec = 1;
        } else {
          $seen = 1;
          cmp_ok($rec->{data}, '==', 9904, 'The data seen is correct');
        }
      }
    );
  }
);

isnt( $seen, undef, 'Did not consume expected record');
isnt( $lastrec, undef, 'Did not see delineator between EPIDs');

dies_ok( sub { $libdtrace->go() }, 'Cannot go() when already going' );
dies_ok( sub { $libdtrace->strcompile('BEGIN { trace(0); }') },
               'Cannot strcompile() when already going' );

lives_ok( sub { $libdtrace->stop(); },
          'stopping consumption of BEGIN clause' );

#
# Now test that END clauses work properly.
#
$libdtrace = undef;
$libdtrace = Devel::libdtrace->new();

lives_ok( sub {
            $libdtrace->strcompile('END { trace(61707); }');
          }, 'compile of END clause should succeed');

lives_ok( sub { $libdtrace->go(); },
          'go() for END clause should succeed' );

$seen     = 0;

# We don't expect this to actually run; the END cause doesn't fire until we
# ->stop() the consumer...
lives_ok(
  sub {
    $libdtrace->consume(
      sub {
        fail("consuming END clause that hasn't fired yet");
      }
    );
  }
);

# This will cause the END clause to fire
lives_ok( sub { $libdtrace->stop(); },
          'stopping consumption of END clause' );

lives_ok(
  sub {
    $libdtrace->consume(
      sub {
        my $probe = shift;
        my $rec   = shift;
        say "PROBE PROVIDER: [" . $probe->{provider} . "]";
        say "  PROBE MODULE: [" . $probe->{module} . "]";
        say "PROBE FUNCTION: [" . $probe->{function} . "]";
        say "    PROBE NAME: [" . $probe->{name} . "]";

        cmp_ok($probe->{provider}, 'eq', 'dtrace',
               'probe provider should be "dtrace"' );
        cmp_ok($probe->{module}, 'eq', '',
               'probe module should be an empty string' );
        cmp_ok($probe->{function}, 'eq', '',
               'probe function should be an empty string' );
        cmp_ok($probe->{name}, 'eq', 'END',
               'probe name should be "END"' );

        if (!$rec) {
          return;
        }

        cmp_ok($rec->{data}, '==', 61707, 'The data seen is correct');
      }
    );
  }
);

#
# Now start consuming a 'tick'ing activity
#
$libdtrace = undef;
$libdtrace = Devel::libdtrace->new();

lives_ok( sub {
            $libdtrace->strcompile('tick-1sec { trace(i++); }');
          }, 'compile of tick-1sec clause should succeed');

lives_ok( sub { $libdtrace->go(); },
          'go() for tick-1sec clause should succeed' );

my ($secs, $val);

my $loop = IO::Async::Loop->new;

my $iterations;
my $timer;
$timer = IO::Async::Timer::Periodic->new(
   interval => 1,
 
   on_tick => sub {
     $iterations++;

     $libdtrace->consume(
       sub {
         my ($probe, $rec) = @_;

         if (!$rec) { return; }

         if (($val = $rec->{data}) > 5) {
           # Stop the timer
           $loop->remove( $timer );
           $loop->loop_stop();
         }
         diag Dumper( $rec );
       }
     );
   },
);
 
$timer->start;
 
$loop->add( $timer );
 
$loop->run;

done_testing();
