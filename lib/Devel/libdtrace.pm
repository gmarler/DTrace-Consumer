package Devel::libdtrace;

use strict;
use warnings;
use XSLoader;

# VERSION

# ABSTRACT: Perl XS interface to libdtrace

XSLoader::load('Devel::libdtrace', $VERSION);

1;

__END__

=head1 NAME

Devel::libdtrace - Perl XS interface to libdtrace library

=method new

constructs a new DTrace library handle

=method version

States the current version of this module
