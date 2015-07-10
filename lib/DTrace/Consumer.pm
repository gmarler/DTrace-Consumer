package DTrace::Consumer;

use strict;
use warnings;
use XSLoader;

# VERSION

# ABSTRACT: A DTrace Consumer implemented in Perl XS

XSLoader::load('DTrace::Consumer', $VERSION);

1;

__END__

=head1 NAME

DTrace::Consumer - A DTrace Consumer implemented in Perl XS

=method new

constructs a new DTrace Consumer library handle

my $dtc = DTrace::Consumer->new();

=method version

States the current version of this module

=method setopt

Allows setting DTrace options, with or without arguments.

Will throw an exception if the option or argument are invalid.

$dtc->setopt("zdefs");

$dtc->setopt("bufsize","512k");

=method strcompile

Takes one argument, a DTrace program, as a single string scalar.

Throws an exception if the program is invalid.

$dtc->strcompile($prog_scalar);

This does NOT start the DTrace, it just compiles it in preparation for running it.

=method go

Starts the DTrace script that has been previous strcompile()'ed.

Will throw an exception if the script cannot be run.

=method stop

Stops a currently running DTrace run, previously put into place by the combination
strcompile() / go() combination.

Throws an exception if a stop could not be performed.

=method consume

Used to consume non-aggregation type output from DTrace.

TODO: Describe callback that has to be provided.

=method aggmin

Constant representing the smallest value an aggregation can store.
This is defined as the minimum 64-bit signed integer.

=method aggmax

Constant representing the largest value an aggregation can store.
This is defined as the highest 64-bit signed integer.

=method aggclear

Clears an aggregation

=method aggwalk

Allows walking the data collected by an aggregation and processing it.

TODO: Describe callback that has to be provided.



