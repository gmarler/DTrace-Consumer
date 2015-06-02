use strict;
use warnings;

use Test::Most;

use_ok( 'Devel::libdtrace ' );

my $libdtrace = Devel::libdtrace->new();

isa_ok( $libdtrace, 'Devel::libdtrace' );
can_ok( $libdtrace, 'setopt'           );

lives_ok( sub { $libdtrace->setopt("zdefs"); },
          'One argument form should live' );

lives_ok( sub { $libdtrace->setopt("bufsize","512k"); },
          'Two argument form should live' );

dies_ok( sub { $libdtrace->setopt(""); },
         'Should die trying to set a null option' );

done_testing();

