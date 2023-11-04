package CPAN::Tester::Box;
use Moo;
use v5.20.0;
use if $] <  5.036, experimental => 'signatures';
use if $] >= 5.036, feature      => 'signatures';

our $VERSION = '0.01_00';

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

=head2 handled

Administrative HashRef that keeps track of distributions handled.  This can be
initialised in order to "continue" where one left of.

=head2 last_poll

Administrative Int that keeps track of the last time we polled the mirror.

=cut

use Types::Standard qw< HashRef InstanceOf Int Str >;
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
has last_poll => (
    is  => 'rw',
    isa => Int,
);

=head1 DESCRIPTION

This is a very simple CPAN::Tester box. It polls the mirror for new files every
interval (3600 secs by default) and will call C<< CPAN::Shell->test('$tarball')
>> via C<system()>. Whenever the queue of new files is empty, it will C<sleep()>
for the rest of the polling interval.

By calling C<< CPAN::Shell->test() >>, we assume that you have configured the
CPAN module to create and send test reports (see L<CPAN::Reporter>).

Advice: Run this programme as a separate user on the system, with its own CPAN
configuration. If you choose to install dependencies, use the C<local::lib>
model (or set C<< PERL_MM_OPT=INST_BASE=/home/<user>/tester >>)

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

=head2 $box->handle_queue_item($item)

    $self->tester_per -MCPAN -e "CPAN::Shell->test('$item->{path}')"

=cut

sub handle_queue_item ($self, $item) {
    return if !$item;
    return if $self->handled->{ $item->{path} };
    say STDERR "# $item->{path} $item->{time}" if $self->verbose;

    my @cmd = (
        $self->tester_perl, '-MCPAN', '-e',
        qq{"CPAN::HandleConfig->require_myconfig_or_config;
            CPAN::Shell->o(conf => 'test_report', 1);
            CPAN::Shell->test('$item->{path}');
        "}
    );
    my $cmdln = join(" ", @cmd);
    say STDERR "# $cmdln" if $self->verbose;

    {
        local $ENV{AUTOMATED_TESTING} = 1;
        local $ENV{PERL_MM_USE_DEFAULT} = 1;
        if ($self->verbose > 1) {
            system($cmdln);
        }
        else {
            system("$cmdln 2>&1 >" . devnull());
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
