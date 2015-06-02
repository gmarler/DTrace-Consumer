use strict;
use warnings;

use Test::Most;

use_ok( 'Devel::libdtrace ' );

my $libdtrace = Devel::libdtrace->new();

isa_ok( $libdtrace, 'Devel::libdtrace' );
can_ok( $libdtrace, 'setopt'           );

dies_ok( sub { $libdtrace->setopt(""); },
         'Should die trying to set a null option' );

done_testing();

