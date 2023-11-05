# NAME

CPAN::Tester::Box - A CPAN::Tester box based on [CPAN](https://metacpan.org/pod/CPAN).

# SYNOPSIS

```perl
use CPAN::Tester::RecentUploads;
use CPAN::Tester::Box;

my $recents = CPAN::Tester::RecentUploads->new(
    mirror => 'http://www.cpan.org',
);
my $box = CPAN::Tester::Box->new(
    recent_uploads => $recents,
    poll_interval  => $option{interval},
    tester_perl    => $option{perl},
    verbose        => 1,
);

$box->run();
```

# ATTRIBUTES

## recent\_uploads

_InstanceOf_ [CPAN::Tester::RecentUploads](https://metacpan.org/pod/CPAN%3A%3ATester%3A%3ARecentUploads)

_Required_

## poll\_interval

Interval between polls to the mirror for new files (in seconds).

_Default_: **3600** (1 hour)

## tester\_perl

The perl-binary to use for testing.

_Default_: **$^X**

## verbose

Determines the amount of output, **0 | 1 | 2**.

_Default_: **1**

## install\_tested

Call `CPAN::Shell->install_tested()` at the end.

_Default_: **0**

## handled

Administrative HashRef that keeps track of distributions handled.  This can be
initialised in order to "continue" where one left of.

## last\_poll

Administrative Int that keeps track of the last time we polled the mirror.

# DESCRIPTION

This is a very simple CPAN::Tester box. It polls the mirror for new files every
interval (3600 secs by default) and will call `CPAN::Shell->test('$tarball')` via `system()`. Whenever the queue of new files is empty, it will `sleep()`
for the remainder of the polling interval.

By calling `CPAN::Shell->test()`, we assume that you have configured the
CPAN module to create and send test reports (see [CPAN::Reporter](https://metacpan.org/pod/CPAN%3A%3AReporter)).

Advice: Run this programme as a separate user on the system, with its own CPAN
configuration. If you choose to install dependencies, use the [local::lib](https://metacpan.org/pod/local%3A%3Alib)
model (or set `PERL_MM_OPT=INST_BASE=/home/<user>/perl5lib` and `PERL_MB_OPT=--install_base /home/<user>/perl5lib` yourself).

**WARNING: By running this programme one agrees to run random code on ones
machine. This can be dangerous for that machine! Make sure the user running it,
can do as little harm as posible.**

# COPYRIGHT

© MMXXIII - Abe Timmerman <abeltje@cpan.org>

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
