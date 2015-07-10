use strict;
use warnings;

use Test::Most;

use_ok( 'DTrace::Consumer ' );

my $dtc = DTrace::Consumer->new();

isa_ok( $dtc, 'DTrace::Consumer' );
can_ok( $dtc, 'strcompile'       );

dies_ok( sub { $dtc->strcompile(); },
          'null program should die' );

dies_ok( sub { $dtc->strcompile(""); },
          'Empty program should die' );

lives_ok( sub { $dtc->strcompile("BEGIN"); },
          'Basic BEGIN block should live' );

done_testing();

