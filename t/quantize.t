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
can_ok( $libdtrace, qw( strcompile go aggwalk stop ) );

my $prog = "BEGIN\n{\n";

for (my $i = -32; $i < 32; $i++) {
  $prog .= "\t\@ = quantize($i);\n";
}

$prog .= "}\n";

diag $prog;

lives_ok(
  sub {
    $libdtrace->strcompile($prog);
  },
  'strcompile of quantize program'
);

lives_ok(
  sub {
    $libdtrace->go();
  },
  'Run go() on quantize program'
);

lives_ok(
  sub {
    $libdtrace->aggwalk(
      sub {
        diag Data::Dumper::Dumper( \@_ );
        my ($varid, $key, $val) = @_;

        my $expected =
        [
          [ [ -63, -32 ], 1 ],
          [ [ -31, -16 ], 16 ],
          [ [ -15, -8 ], 8 ],
          [ [ -7, -4 ], 4 ],
          [ [ -3, -2 ], 2 ],
          [ [ -1, -1 ], 1 ],
          [ [ 0, 0 ], 1 ],
          [ [ 1, 1 ], 1 ],
          [ [ 2, 3 ], 2 ],
          [ [ 4, 7 ], 4 ],
          [ [ 8, 15 ], 8 ],
          [ [ 16, 31 ], 16 ],
        ];

        cmp_deeply($val, $expected,
                   'quantize output should match');

        cmp_ok($varid, '==', 1, 'varid should be 1');
        cmp_ok(reftype($key), 'eq', 'ARRAY', 'key should be an arrayref');
        cmp_ok(scalar(@$key), '==', 0, 'key array length should be 0');
        cmp_ok(reftype($val), 'eq', 'ARRAY', 'val should be an arrayref');
      }
    );
  },
  'walking quantize agg shows correct data'
);

done_testing();
