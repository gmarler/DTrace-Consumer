package DTrace::Consumer;

use strict;
use warnings;
use XSLoader;
use ExtUtils::Constant qw(WriteConstants);

WriteConstants(
  NAME => 'DTrace::Consumer',
  NAMES => [ qw(DTRACE_O_NODEV DTRACE_O_NOSYS DTRACE_O_LP64 DTRACE_O_ILP32) ],
);

# VERSION

# ABSTRACT: A DTrace Consumer implemented in Perl XS

XSLoader::load('DTrace::Consumer', $VERSION);

1;

__END__

=head1 NAME

DTrace::Consumer - A DTrace Consumer implemented in Perl XS

=head1 SYNOPSIS

 use DTrace::Consumer;

 my $dtc = DTrace::Consumer->new();

 $dtc->setopt("quiet");
 $dtc->setopt("bufsize","512k");

 my $prog = "
 sched:::on-cpu
 {
   self->on = timestamp;
 }
 
 sched:::off-cpu
 /self->on/
 {
   @ = lquantize((timestamp - self->on) / 1000,
                 0, 10000, 100);
 }
 ";

 $dtc->strcompile($prog);
 $dtc->go();

 $dtc->aggwalk(
   sub {
     my ($varid, $key, $val) = @_;
 
     # ... This is where you handle the aggregations ...
   }
 );

=head1 DESCRIPTION

This module acts as a DTrace Consumer, which allows you, with the proper
privileges, to use Perl to register DTrace scripts and actions.

=method new

constructs a new DTrace Consumer library handle

my $dtc = DTrace::Consumer->new();

=method version

States the current version of this module

=method setopt

Allows setting DTrace options, with or without arguments.

Will throw an exception if the option or argument are invalid.

=over 4

=item *

$dtc->setopt("zdefs");

An example of an option/pragma that doesn't take an argument.

=item *

$dtc->setopt("bufsize","512k");

An example of an option/pragma that does take an argument.

=back

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



