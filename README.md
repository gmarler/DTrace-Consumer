# NAME

DTrace::Consumer - A DTrace Consumer implemented in Perl XS

# SYNOPSIS

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

# DESCRIPTION

This module acts as a DTrace Consumer, which allows you, with the proper
privileges, to use Perl to register DTrace scripts and actions.

constructs a new DTrace Consumer library handle

my $dtc = DTrace::Consumer->new();

States the current version of this module

Allows setting DTrace options, with or without arguments.

Will throw an exception if the option or argument are invalid.

- $dtc->setopt("zdefs");

    An example of an option/pragma that doesn't take an argument.

- $dtc->setopt("bufsize","512k");

    An example of an option/pragma that does take an argument.

Takes one argument, a DTrace program, as a single string scalar.

Throws an exception if the program is invalid.

$dtc->strcompile($prog\_scalar);

This does NOT start the DTrace, it just compiles it in preparation for running it.

Starts the DTrace script that has been previous strcompile()'ed.

Will throw an exception if the script cannot be run.

Stops a currently running DTrace run, previously put into place by the combination
strcompile() / go() combination.

Throws an exception if a stop could not be performed.

Used to consume non-aggregation type output from DTrace.

TODO: Describe callback that has to be provided.

Constant representing the smallest value an aggregation can store.
This is defined as the minimum 64-bit signed integer.

Constant representing the largest value an aggregation can store.
This is defined as the highest 64-bit signed integer.

Clears an aggregation

Allows walking the data collected by an aggregation and processing it.

TODO: Describe callback that has to be provided.

# POD ERRORS

Hey! **The above document had some coding errors, which are explained below:**

- Around line 44:

    Unknown directive: =method

- Around line 50:

    Unknown directive: =method

- Around line 54:

    Unknown directive: =method

- Around line 76:

    Unknown directive: =method

- Around line 86:

    Unknown directive: =method

- Around line 92:

    Unknown directive: =method

- Around line 99:

    Unknown directive: =method

- Around line 105:

    Unknown directive: =method

- Around line 110:

    Unknown directive: =method

- Around line 115:

    Unknown directive: =method

- Around line 119:

    Unknown directive: =method
