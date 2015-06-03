use strict;
use warnings;

use Test::Most;

use_ok( 'Devel::libdtrace ' );

my $libdtrace = Devel::libdtrace->new();

isa_ok( $libdtrace, 'Devel::libdtrace' );
can_ok( $libdtrace, 'go'       );


lives_ok( sub { $libdtrace->strcompile("BEGIN"); },
          'Basic BEGIN block should live' );

lives_ok( sub { $libdtrace->go(); },
          'Enabling of simple DTrace should live' );

undef $libdtrace;
$libdtrace = Devel::libdtrace->new();

# TODO: figure out why go when nothing has been enabled fails to fail
#dies_ok( sub { $libdtrace->go(); },
#          'Non-compiled go call should die' );

done_testing();

