use strict;
use warnings;

use Test::Most;
use IO::File;

use_ok( 'DTrace::Consumer' );

my $dtc = DTrace::Consumer->new();

isa_ok( $dtc, 'DTrace::Consumer' );
can_ok( $dtc, 'setopt'           );

throws_ok( sub { $dtc->setopt(); },
           qr/Usage:/, 'NULL option');
throws_ok( sub { $dtc->setopt(""); },
           qr/Invalid\soption\sname/,
           'Empty string option' );
throws_ok( sub { $dtc->setopt('bogusoption'); },
           qr/Invalid\soption\sname/,
           'Bogus option' );
throws_ok( sub { $dtc->setopt('bufpolicy'); },
           qr/Invalid\svalue\sfor\sspecified\soption/,
           'bufpolicy, which requires a value, with no value' );
throws_ok( sub { $dtc->setopt('bufpolicy', 100); },
           qr/Value\smust\sbe\sa\sstring/,
           'bufpolicy, with a numeric value' );

#$dtc->setopt('quiet', 1);

throws_ok( sub { $dtc->setopt('bufpolicy', 1); },
           qr/Value\smust\sbe\sa\sstring/,
           'bufpolicy, with a numeric value #2' );
throws_ok( sub { $dtc->setopt('dynvarsize', 1); },
           qr/Value\smust\sbe\sa\sstring/,
           'dynvarsize, with a numeric value');
throws_ok( sub { $dtc->setopt('dynvarsize', 1.23); },
           qr/Value\smust\sbe\sa\sstring/,
           'dynvarsize, with a floating point value' );

#$dtc->setopt('quiet', 1024);

throws_ok( sub { $dtc->setopt('quiet', { foo => 1024 } ); },
           qr/Value\smust\sbe\sa\sstring/,
           'quiet, with a hashref value' );
throws_ok( sub { $dtc->setopt('quiet', [ 0 ] ); },
           qr/Value\smust\sbe\sa\sstring/,
           'quiet, with an arrayref value' );
throws_ok( sub { $dtc->setopt('quiet', 1.024 ); },
           qr/Value\smust\sbe\sa\sstring/,
           'quiet, with a floating point value' );
throws_ok( sub { $dtc->setopt('quiet', IO::File->new("/etc/group","<") ); },
           qr/Value\smust\sbe\sa\sstring/,
           'quiet, with a DateTime object value' );


lives_ok( sub { $dtc->setopt('quiet'); },
          'quiet, set properly' );
lives_ok( sub { $dtc->setopt('dynvarsize', '16m'); },
          'dynvarsize, with 16m value' );
lives_ok( sub { $dtc->setopt('bufpolicy', 'ring'); },
          'bufpolicy, with "ring" value' );

done_testing();

