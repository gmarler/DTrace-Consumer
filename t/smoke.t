use strict;
use warnings;

use Test::More;

use Devel::libdtrace;

my $libdtrace = Devel::libdtrace->new();

isa_ok( $libdtrace, 'Devel::libdtrace' );
can_ok( $libdtrace, 'version'             );

is ($libdtrace->version, '0.0.1',
    'Devel::libdtrace library is version 0.0.1' );

done_testing();

