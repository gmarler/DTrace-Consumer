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

for (my $i = -5; $i < 15; $i++) {
  $prog .= "\t\@ = lquantize($i, 0, 10, 2);\n";
}

$prog .= "}\n";

diag $prog;

lives_ok(
  sub {
    $libdtrace->strcompile($prog);
  },
  'strcompile of 1st lquantize program'
);

lives_ok(
  sub {
    $libdtrace->go();
  },
  'Run go() on 1st lquantize program'
);

lives_ok(
  sub {
    $libdtrace->aggwalk(
      sub {
        diag Data::Dumper::Dumper( \@_ );
        my ($varid, $key, $val) = @_;

        my $expected = 
        [
          [ [ '-9223372036854775808', -1 ], 5 ],
          [ [ 0, 1 ], 2 ],
          [ [ 2, 3 ], 2 ],
          [ [ 4, 5 ], 2 ],
          [ [ 6, 7 ], 2 ],
          [ [ 8, 9 ], 2 ],
          [ [ 10, '9223372036854775807' ], 5 ]
        ];

        cmp_deeply($val, $expected,
                   'lquantize output 1 should match');

        cmp_ok($varid, '==', 1, 'varid should be 1');
        cmp_ok(reftype($key), 'eq', 'ARRAY', 'key should be an arrayref');
        cmp_ok(scalar(@$key), '==', 0, 'key array length should be 0');
        cmp_ok(reftype($val), 'eq', 'ARRAY', 'val should be an arrayref');
      }
    );
  },
  'walking lquantize agg 1 shows correct data'
);

undef $libdtrace;


$libdtrace = Devel::libdtrace->new();

isa_ok( $libdtrace, 'Devel::libdtrace' );

$prog = "BEGIN\n{\n";

for (my $i = -100; $i < 100; $i++) {
  $prog .= "\t\@ = lquantize($i, -200, 200, 10);\n";
}

$prog .= "}\n";

diag $prog;

lives_ok(
  sub {
    $libdtrace->strcompile($prog);
  },
  'strcompile of 2nd lquantize program'
);

lives_ok(
  sub {
    $libdtrace->go();
  },
  'Run go() on 2nd lquantize program'
);

lives_ok(
  sub {
    $libdtrace->aggwalk(
      sub {
        diag Data::Dumper::Dumper( \@_ );
        my ($varid, $key, $val) = @_;

        my $expected =
        [
          [ [ -100, -91 ], 10 ],
          [ [ -90, -81 ], 10 ],
          [ [ -80, -71 ], 10 ],
          [ [ -70, -61 ], 10 ],
          [ [ -60, -51 ], 10 ],
          [ [ -50, -41 ], 10 ],
          [ [ -40, -31 ], 10 ],
          [ [ -30, -21 ], 10 ],
          [ [ -20, -11 ], 10 ],
          [ [ -10, -1 ], 10 ],
          [ [ 0, 9 ], 10 ],
          [ [ 10, 19 ], 10 ],
          [ [ 20, 29 ], 10 ],
          [ [ 30, 39 ], 10 ],
          [ [ 40, 49 ], 10 ],
          [ [ 50, 59 ], 10 ],
          [ [ 60, 69 ], 10 ],
          [ [ 70, 79 ], 10 ],
          [ [ 80, 89 ], 10 ],
          [ [ 90, 99 ], 10 ]
        ];


        cmp_deeply($val, $expected,
                   'lquantize output 2 should match');

        cmp_ok($varid, '==', 1, 'varid should be 1');
        cmp_ok(reftype($key), 'eq', 'ARRAY', 'key should be an arrayref');
        cmp_ok(scalar(@$key), '==', 0, 'key array length should be 0');
        cmp_ok(reftype($val), 'eq', 'ARRAY', 'val should be an arrayref');
      }
    );
  },
  'walking lquantize agg 2 shows correct data'
);

done_testing();
