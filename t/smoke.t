use strict;
use warnings;

use Test::More;

use DTrace::Consumer;

my $dtc = DTrace::Consumer->new();

isa_ok( $dtc, 'DTrace::Consumer' );
can_ok( $dtc, 'version'             );

is ($dtc->version, '0.0.2',
    'DTrace::Consumer library is version 0.0.2' );

done_testing();

