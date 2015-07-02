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

lives_ok(
  sub {
    $libdtrace->strcompile('BEGIN { @["foo", "bar", 9904, 61707] = count(); }');
    $libdtrace->go();
  },
  'strcompile of a BEGIN clause with an aggregation'
);

lives_ok(
  sub {
    $libdtrace->aggwalk(
      sub {
        my ($varid, $key_aref, $val) = @_;

        cmp_ok($varid, '==', 1, 'varid equals 1');
        cmp_ok(reftype($key_aref), 'eq', 'ARRAY',
               '$key_aref is an array reference');
        cmp_ok(scalar(@$key_aref), '==', 4,
               '@$key_aref has a length of 4 elements');
        cmp_ok($key_aref->[0], 'eq', "foo",
               '$key_aref->[0] is "foo"');
        cmp_ok($key_aref->[1], 'eq', "bar",
               '$key_aref->[1] is "bar"');
        cmp_ok($key_aref->[2], '==', 9904,
               '$key_aref->[2] is 9904');
        cmp_ok($key_aref->[3], '==', 61707,
               '$key_aref->[3] is 61707');

        # diag Dumper( $varid );
        # diag Dumper( $key_aref );
        # diag Dumper( $val );
      }
    );
  },
  'walking aggregation show correct data'
);


lives_ok(
  sub {
    $libdtrace->stop();
  },
  'Stop DTrace'
);

$libdtrace = undef;

$libdtrace = Devel::libdtrace->new();

sub lq {
  my $val = shift;

  return ( "$val, 3, 7, 3" );
}

my $aggacts = {
  max   => { args     => [ '10', '20' ],
             expected => 20 },
  min   => { args     => [ '10', '20' ],
             expected => 10 },
  count => { args     => [ '', '' ],
             expected => 2 },
  sum   => { args     => [ '10', '20' ],
             expected => 30 },
  avg   => { args     => [ '30', '1'  ],
             expected => 15.5 },
  quantize => { args => [ '2', '4', '5', '8' ],
                expected => [
                             [ [ 2,  3 ], 1 ],
                             [ [ 4,  7 ], 2 ],
                             [ [ 8, 15 ], 1 ],
                            ] },
  lquantize => { args => [ lq(2), lq(4), lq(5), lq(8) ],
                 expected => [
                              [ [ $libdtrace->aggmin(), 2 ], 1 ],
                              [ [ 3, 5 ], 2 ],
                              [ [ 6, $libdtrace->aggmax() ], 1 ],
                             ] },
};

diag "AGGACTS:\n" . Dumper($aggacts);

my $varids = [ '' ];  # initialize with a 0'th item
my $prog = "BEGIN\n{\n";

foreach my $act (keys %$aggacts) {
  push @$varids, $act;

  for (my $i = 0; $i < scalar(@{$aggacts->{$act}->{args}}); $i++) {
    $prog .= "\t\@agg$act = $act(" . $aggacts->{$act}->{args}->[$i] . ");\n";
  }
}

$prog .= "}\n";

diag "VARIDs: " . Dumper( $varids );
diag "PROGRAM:\n$prog";

lives_ok(
  sub {
    $libdtrace->strcompile($prog);
  },
  'strcompile of aggregation program'
);

lives_ok(
  sub {
    $libdtrace->go();
  },
  'go() of aggregation program'
);

$libdtrace->aggwalk(
  sub {
    my ($varid, $key, $val) = @_;
    ok($varids->[$varid], 'invalid variable ID ' . $varid);
    ok($aggacts->{$varids->[$varid]}, 'unknown variable ID ' . $varid);

    my $act = $aggacts->{$varids->[$varid]};
    cmp_deeply($act->{expected}, $val);

    #  diag Dumper($varid);
    #  diag Dumper($key);
    #  diag Dumper($val);
  }
);

done_testing();

