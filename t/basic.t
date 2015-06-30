use strict;
use warnings;
use v5.18.1;
use feature qw(say);

use Test::Most;

use_ok( 'Devel::libdtrace ' );

my $libdtrace = Devel::libdtrace->new();

isa_ok( $libdtrace, 'Devel::libdtrace' );
can_ok( $libdtrace, qw( strcompile setopt go consume stop ) );

dies_ok( sub { $libdtrace->strcompile(); } );
throws_ok( sub { $libdtrace->strcompile(61707); },
           qr/Program\smust\sbe\sa\sstring/,
           'strcompile with an integer, rather than a string' );
dies_ok( sub { $libdtrace->strcompile('this is not D'); } );
dies_ok( sub { $libdtrace->strcompile('bogus-probe { trace(0); }'); } );

# TODO: Test output of this
lives_ok( sub { $libdtrace->strcompile('BEGIN { trace(9904); }'); } );

dies_ok( sub { $libdtrace->setopt(); } );
dies_ok( sub { $libdtrace->setopt('bogusoption'); } );
dies_ok( sub { $libdtrace->setopt('bufpolicy'); } );
dies_ok( sub { $libdtrace->setopt('bufpolicy', 100); } );

lives_ok( sub { $libdtrace->setopt('bufpolicy', 'ring'); },
          'set bufpolicy of "ring"');
lives_ok( sub { $libdtrace->setopt('bufpolicy', 'switch'); },
          'set bufpolicy of "switch"');

lives_ok( sub { $libdtrace->go(); } );

my ($seen, $lastrec);

lives_ok(
  sub {
    $libdtrace->consume(
      sub testbasic {
        my ($probe, $rec) = @_;
        say "PROBE PROVIDER: [$probe->provider]";
        say "  PROBE MODULE: [$probe->module]";
        say "PROBE FUNCTION: [$probe->function]";
        say "    PROBE NAME: [$probe->name]";

        if (!$rec) {
          cmp_ok($seen, '==', 1, 'Data was seen');
          $lastrec = 1;
        } else {
          $seen = 1;
          cmp_ok($rec->data, '==', 9904, 'The data seen is correct');
        }
      }
    );
  }
);

lives_ok( sub { $libdtrace->stop(); } );

done_testing();


