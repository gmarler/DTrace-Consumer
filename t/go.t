use strict;
use warnings;

use Test::Most;

use_ok( 'DTrace::Consumer' );

my $dtc = DTrace::Consumer->new();

isa_ok( $dtc, 'DTrace::Consumer' );
can_ok( $dtc, 'go'       );


lives_ok( sub { $dtc->strcompile("BEGIN"); },
          'Basic BEGIN block should live' );

lives_ok( sub { $dtc->go(); },
          'Enabling of simple DTrace should live' );

undef $dtc;
$dtc = DTrace::Consumer->new();

# TODO: figure out why go when nothing has been enabled fails to fail
#dies_ok( sub { $dtc->go(); },
#          'Non-compiled go call should die' );

done_testing();

