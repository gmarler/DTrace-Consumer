use strict;
use warnings;

use Test::Most;

use_ok( 'DTrace::Consumer ' );

my $dtc = DTrace::Consumer->new();

isa_ok( $dtc, 'DTrace::Consumer' );
can_ok( $dtc, 'setopt'           );

lives_ok( sub { $dtc->setopt("zdefs"); },
          'One argument form should live' );

lives_ok( sub { $dtc->setopt("bufsize","512k"); },
          'Two argument form should live' );

dies_ok( sub { $dtc->setopt(""); },
         'Should die trying to set a null option' );

done_testing();

