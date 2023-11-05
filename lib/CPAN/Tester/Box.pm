package CPAN::Tester::Box;
use Moo;
use v5.20.0;
use if $] <  5.036, experimental => 'signatures';
use if $] >= 5.036, feature      => 'signatures';

our $VERSION = "0.01_03";

use File::Spec::Functions qw< devnull >;
use DateTime;

=head1 NAME

CPAN::Tester::Box - A CPAN::Tester box based on L<CPAN>.

=head1 SYNOPSIS

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

=head1 ATTRIBUTES

=head2 recent_uploads

I<InstanceOf> L<CPAN::Tester::RecentUploads>

I<Required>

=head2 poll_interval

Interval between polls to the mirror for new files (in seconds).

I<Default>: B<3600> (1 hour)

=head2 tester_perl

The perl-binary to use for testing.

I<Default>: B<$^X>

=head2 verbose

Determines the amount of output, B<0 | 1 | 2>.

I<Default>: B<1>

=head2 install_tested

Call C<< CPAN::Shell->install_tested() >> at the end.

I<Default>: B<0>

=head2 o_conf

A HashRef of CPAN configuration options to set for testing.

I<Default>: B<{ test_report: 1 }>

=head2 ignore

An ArrayRef of regex-patterns to test against the path:
C<A/AU/AUTHORNAME/Dist-Thing-42.01.tgz>

I<Default>: B<[ ]> (no ignore)

=head2 skip_initial

We start by collecting the recent uploads from the last week, if one wants to
skip these uploads, pass C<< skip_initial => 1 >> to the constructor.

I<Default>: B<0>

=head2 handled

Administrative HashRef that keeps track of distributions handled.  This can be
initialised in order to "continue" where one left of.

=head2 last_poll

Administrative Int that keeps track of the last time we polled the mirror.

=cut

use Types::Standard qw< ArrayRef Bool HashRef InstanceOf Int Str >;
has recent_uploads => (
    is       => 'ro',
    isa      => InstanceOf ['CPAN::Tester::RecentUploads'],
    required => 1,
);
has handled => (
    is      => 'ro',
    isa     => HashRef,
    default => sub { {} },
);
has poll_interval => (
    is      => 'ro',
    isa     => Int,
    default => sub { 60 * 60 },
);
has tester_perl => (
    is      => 'ro',
    isa     => Str,
    default => sub {$^X},
);
has verbose => (
    is      => 'ro',
    isa     => Int,
    default => 1,
);
has install_tested => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);
has o_conf => (
    is      => 'ro',
    isa     => HashRef,
    default => sub { { test_report => 1 } },
);
has ignore => (
    is      => 'ro',
    isa     => ArrayRef,
    default => sub { [] },
);
has skip_initial => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);
has last_poll => (
    is  => 'rw',
    isa => Int,
);

=head1 DESCRIPTION

This is a very simple CPAN::Tester box. It polls the mirror for new files every
interval (3600 secs by default) and will call C<< CPAN::Shell->test('$tarball')
>> via C<system()>. Whenever the queue of new files is empty, it will C<sleep()>
for the remainder of the polling interval.

By calling C<< CPAN::Shell->test() >>, we assume that you have configured the
CPAN module to create and send test reports (see L<CPAN::Reporter>).

Advice: Run this programme as a separate user on the system, with its own CPAN
configuration. If you choose to install dependencies, use the L<local::lib>
model (or set C<< PERL_MM_OPT=INST_BASE=/home/<user>/perl5lib >> and C<<
PERL_MB_OPT=--install_base /home/<user>/perl5lib >> yourself).

B<WARNING: By running this programme one agrees to run random code on ones
machine. This can be dangerous for that machine! Make sure the user running it,
can do as little harm as posible.>

=begin documentation

=head2 $box->get_recent_queue($interval)

Returns an ArrayRef with items from the last C<$interval> but without those that
are in C<< $self->handled >>.

=cut

sub get_recent_queue ($self, $interval) {
    $self->last_poll(time());

    my $all_recent = $self->recent_uploads->get_recent($interval) // [ ];
    if ($self->verbose and @$all_recent) {
        my $last = $all_recent->[-1];
        say STDERR "# Last($interval): $last->{path} $last->{time}"
    }

    my $recent = [ grep {
        ! exists($self->handled->{$_->{path}})
    } @$all_recent ];
    return $recent;
}

=head2 $box->wants_ignore($item)

=cut

sub wants_ignore ($self, $item) {
    my @ignore = grep {
        $item->{path} =~ m{$_}
    } @{ $self->ignore };
    return @ignore ? [ @ignore ] : ();
}

=head2 $self->_test_command($item)

This returns an ArrayRef with the elements of the command to run.

mostly to improve testability...

=cut

sub _test_command ($self, $item) {
    my $install_tested = $self->install_tested
        ? 'CPAN::Shell->install_tested();'
        : "";

    my @o_conf = map {
        "CPAN::Shell->o(conf => '$_', '@{[ $self->o_conf->{$_} ]}');"
    } sort keys %{ $self->o_conf };

    my $indent = " " x 12;
    my @cmd = (
        sprintf('"%s"', $self->tester_perl),
        '"-MCPAN"',
        '"-e"',
        qq/"
            CPAN::HandleConfig->require_myconfig_or_config;
            @{[ join("\n$indent", @o_conf) ]}
            CPAN::Shell->test('$item->{path}');
            $install_tested
        "/
    );
    return \@cmd;
}

=head2 $box->handle_queue_item($item)

    $self->tester_per -MCPAN -e "CPAN::Shell->test('$item->{path}')"

=cut

sub handle_queue_item ($self, $item) {
    return if !$item;
    return if $self->handled->{ $item->{path} };
    if (my $sp = $self->wants_ignore($item)) {
        say STDERR "# IGNORE: $item->path $item->{time}" if $self->verbose;
        say STDERR "# IPAT: @$sp" if $self->verbose;
        $self->handled->{ $item->{path} }++;
        return 1;
    }
    say STDERR "# $item->{path} $item->{time}" if $self->verbose;

    my $cmd = $self->_test_command($item);
    my $cmdln = join(" ", @$cmd);
    say STDERR "# $cmdln" if $self->verbose;

    {
        local $ENV{AUTOMATED_TESTING} = 1;
        local $ENV{PERL_MM_USE_DEFAULT} = 1;
        if (open(my $td, '-|', "$cmdln 2>&1")) {
            while (my $line = <$td>) {
                if ($self->verbose > 1) {
                    print STDERR $line;
                }
                elsif ($self->verbose) {
                    print STDERR "# $line" if $line =~ m{^CPAN::Reporter:};
                }
            }
            close($td) or say STDERR "# Error on close-pipe: $!";
        }
        else {
            say STDERR "# Couldn't open-pipe: $! ($?)";
            my $redir = $self->verbose ? '1>&2' : '2>&1 >' . devnull;
            system("$cmdln $redir");
        }
    }

    $self->handled->{ $item->{path} }++;
    return 1;
}

=head2 $box->top_up_queue($queue)

If we are at or over the C<< $self->poll_interval >> time, just push new items
on the queue.

=cut

sub top_up_queue ($self, $queue) {
    my $interval = time() - $self->last_poll - $self->poll_interval;
    push(@$queue, @{$self->get_recent_queue('6h')}) if $interval >= 0;
    return 1;
}

=head2 $box->handle_queue($queue)

While there are queue-items, I<handle-item> and I<top-up-queue>

=cut

sub handle_queue ($self, $queue) {
    while (@$queue) {
        my $item = shift(@$queue);
        $self->handle_queue_item($item);
        $self->top_up_queue($queue);
    }
}

=head2 $box->wait_for_new($queue)

Sleep until the next C<< $self->poll_intervall >> and I<top-up-queue>.

=cut

sub wait_for_new ($self, $queue) {
    my $interval = $self->poll_interval - (time() - $self->last_poll);
    my $now = DateTime->now(); $now->set_time_zone($ENV{TZ}) if $ENV{TZ};
    say STDERR sprintf(
        "# wait_for_new: sleep(%u) of %u %s",
        $interval, $self->poll_interval, $now->strftime("%a %F %T %z")
    ) if $self->verbose;

    sleep($interval) if $interval > 0;
    return $self->top_up_queue($queue);
}

=head2 $box->run

Fetch recent items (1W) and endlessly repeat I<handle-queue>, I<wait-for-new>.

=cut

sub run ($self) {
    my $queue = $self->get_recent_queue('1W');
    if ($self->skip_initial) {
        while (@$queue) {
            my $item = shift(@$queue);
            say STDERR "# SKIP $item->{path} $item->{time}" if $self->verbose;
            $self->handled->{ $item->{path} }++;
        }
    }
    while (1) {
        $self->handle_queue($queue);
        $self->wait_for_new($queue);
    }
}

use namespace::autoclean;
1;

=end documentation

=head1 COPYRIGHT

E<copy> MMXXIII - Abe Timmerman <abeltje@cpan.org>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
