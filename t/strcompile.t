use strict;
use warnings;

use Test::Most;

use_ok( 'Devel::libdtrace ' );

my $libdtrace = Devel::libdtrace->new();

isa_ok( $libdtrace, 'Devel::libdtrace' );
can_ok( $libdtrace, 'strcompile'       );

dies_ok( sub { $libdtrace->strcompile(); },
          'null program should die' );

dies_ok( sub { $libdtrace->strcompile(""); },
          'Empty program should die' );

lives_ok( sub { $libdtrace->strcompile("BEGIN"); },
          'Basic BEGIN block should live' );

done_testing();

