use strict;
use warnings;
use v5.18.1;
use feature qw(say);

use Test::Most;
use Data::Dumper;

use_ok( 'Devel::libdtrace ' );

my $libdtrace = Devel::libdtrace->new();

isa_ok( $libdtrace, 'Devel::libdtrace' );
can_ok( $libdtrace, qw( strcompile go consume stop ) );

lives_ok(
  sub {
    $libdtrace->strcompile('BEGIN { printf("{ foo: %d", 123); printf(", bar: %d", 456); }');
    $libdtrace->go();
  },
  'strcompile of a BEGIN clause with printf'
);

lives_ok(
  sub {
    $libdtrace->consume(
      sub {
        my ($probe, $rec) = @_;
        cmp_ok($probe->{provider}, 'eq', 'dtrace',
               'probe provider is dtrace');
        cmp_ok($probe->{module}, 'eq', '',
               'probe module is empty string');
        cmp_ok($probe->{function}, 'eq', '',
               'probe function is empty string');
        cmp_ok($probe->{name}, 'eq', 'BEGIN',
               'probe name is BEGIN');

        diag Dumper( $probe );
        diag Dumper( $rec );
      }
    );
  },
  'Consumption of printf produced proper output'
);


lives_ok(
  sub {
    $libdtrace->stop();
  },
  'Stop DTrace'
);


done_testing();

