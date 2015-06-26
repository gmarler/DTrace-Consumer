use strict;
use warnings;

use Test::Most;
use IO::File;

use_ok( 'Devel::libdtrace' );

my $libdtrace = Devel::libdtrace->new();

isa_ok( $libdtrace, 'Devel::libdtrace' );
can_ok( $libdtrace, 'setopt'           );

throws_ok( sub { $libdtrace->setopt(); },
           qr/Usage:/, 'NULL option');
throws_ok( sub { $libdtrace->setopt(""); },
           qr/Invalid\soption\sname/,
           'Empty string option' );
throws_ok( sub { $libdtrace->setopt('bogusoption'); },
           qr/Invalid\soption\sname/,
           'Bogus option' );
throws_ok( sub { $libdtrace->setopt('bufpolicy'); },
           qr/Invalid\svalue\sfor\sspecified\soption/,
           'bufpolicy, which requires a value, with no value' );
throws_ok( sub { $libdtrace->setopt('bufpolicy', 100); },
           qr/Value\smust\sbe\sa\sstring/,
           'bufpolicy, with a numeric value' );

#$libdtrace->setopt('quiet', 1);

throws_ok( sub { $libdtrace->setopt('bufpolicy', 1); },
           qr/Value\smust\sbe\sa\sstring/,
           'bufpolicy, with a numeric value #2' );
throws_ok( sub { $libdtrace->setopt('dynvarsize', 1); },
           qr/Value\smust\sbe\sa\sstring/,
           'dynvarsize, with a numeric value');
throws_ok( sub { $libdtrace->setopt('dynvarsize', 1.23); },
           qr/Value\smust\sbe\sa\sstring/,
           'dynvarsize, with a floating point value' );

#$libdtrace->setopt('quiet', 1024);

throws_ok( sub { $libdtrace->setopt('quiet', { foo => 1024 } ); },
           qr/Value\smust\sbe\sa\sstring/,
           'quiet, with a hashref value' );
throws_ok( sub { $libdtrace->setopt('quiet', [ 0 ] ); },
           qr/Value\smust\sbe\sa\sstring/,
           'quiet, with an arrayref value' );
throws_ok( sub { $libdtrace->setopt('quiet', 1.024 ); },
           qr/Value\smust\sbe\sa\sstring/,
           'quiet, with a floating point value' );
throws_ok( sub { $libdtrace->setopt('quiet', IO::File->new("/etc/group","<") ); },
           qr/Value\smust\sbe\sa\sstring/,
           'quiet, with a DateTime object value' );


lives_ok( sub { $libdtrace->setopt('quiet'); },
          'quiet, set properly' );
lives_ok( sub { $libdtrace->setopt('dynvarsize', '16m'); },
          'dynvarsize, with 16m value' );
lives_ok( sub { $libdtrace->setopt('bufpolicy', 'ring'); },
          'bufpolicy, with "ring" value' );

done_testing();

