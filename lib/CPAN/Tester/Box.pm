package CPAN::Tester::Box;
use Moo;
use v5.36.1;

use Capture::Tiny qw< capture >;
use DateTime;
use DDP;

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
has last_poll => (
    is  => 'rw',
    isa => Int,
);

sub get_recent_queue ($self, $interval) {
    $self->last_poll(time());

    my $all_recent = $self->recent_uploads->get_recent($interval) // [ ];
    say STDERR "# Last($interval): " . np($all_recent->[-1], colored => 1)
        if @$all_recent;

    my $recent = [ grep {
        ! exists($self->handled->{$_->{path}})
    } @$all_recent ];
    return $recent;
}

sub handle_queue_item ($self, $item) {
    return if !$item;
    return if $self->handled->{ $item->{path} };
    say STDERR "# $item->{path} " . DateTime->from_epoch(epoch => $item->{epoch});

    my @cmd = ($self->tester_perl, '-MCPAN', '-e', qq{"CPAN::Shell->test('$item->{path}')"});
    say STDERR "# " . join(" ", @cmd);
    my ($stdout, $stderr, $exit) = capture { system(@cmd) };
    say STDERR "# test-out: $stdout";

    $self->handled->{ $item->{path} }++;
    return 1;
}

sub top_up_queue ($self, $queue) {
    my $interval = time() - $self->last_poll - $self->poll_interval;
    push(@$queue, @{$self->get_recent_queue('6h')}) if $interval >= 0;
    return 1;
}

sub handle_queue ($self, $queue) {
    while (@$queue) {
        my $item = shift(@$queue);
        $self->handle_queue_item($item);
        $self->top_up_queue($queue);
    }
}

sub wait_for_new ($self, $queue) {
    my $interval = $self->poll_interval - (time() - $self->last_poll);
    my $now = DateTime->now(); $now->set_time_zone($ENV{TZ}) if $ENV{TZ};
    say STDERR sprintf(
        "# wait_for_new: sleep(%u) of %u %s",
        $interval, $self->poll_interval, $now->strftime("%a %F %T %z")
    );

    sleep($interval) if $interval > 0;
    return $self->top_up_queue($queue);
}

sub run ($self) {
    my $queue = $self->get_recent_queue('1W');
    while (1) {
        $self->handle_queue($queue);
        $self->wait_for_new($queue);
    }
}

use namespace::autoclean;
1;

=pod
    
=cut
