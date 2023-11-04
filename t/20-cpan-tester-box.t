#! perl -I. -w
use t::Test::abeltje;
use v5.20.0;
use if $] <  5.036, experimental => 'signatures';
use if $] >= 5.036, feature      => 'signatures';

use Config;
use Test::MockObject;

plan skipall => "Need `alarm` and \$SIG{ALRM} for this test"
    if $Config{d_alarm} ne 'define';

use CPAN::Tester::Box;

{
    (my $recent_uploads = Test::MockObject->new)->set_isa('CPAN::Tester::RecentUploads');
    $recent_uploads->set_always(interval => '1W');
    my $time;
    $recent_uploads->set_series(
        get_recent => [
            {
                epoch => $time = time() - 120,
                path  => 'A/AB/ABELTJE/CPAN-Tester-Box-0.01_01.tar.gz',
                time  => DateTime->from_epoch(epoch => $time),
            },
            {
                epoch => $time = time() - 60,
                path  => 'A/AB/ABELTJE/CPAN-Tester-Box-0.02.tar.gz',
                time  => DateTime->from_epoch(epoch => $time),
            },
        ],
        [
            {
                epoch => $time = time(),
                path  => 'A/AB/ABELTJE/Any-Other-1.03.tgz',
                time  => DateTime->from_epoch(epoch => $time),
            },
        ],
        [],
    );

    no warnings 'redefine';
    local *CPAN::Tester::Box::handle_queue_item = sub ($self, $item) {
        my $rsleep = int(rand(2 * $self->poll_interval)) + 1;
        say STDERR "# Overwrite: $item->{path} $item->{time} (sleeps $rsleep)";

        sleep($rsleep); # represents the `make test`

        say STDERR "Random output for command, verbose > 1" if $self->verbose > 1;
        $self->handled->{$item->{path}}++;
    };

    my $box = CPAN::Tester::Box->new(
        recent_uploads => $recent_uploads,
        poll_interval  => 3,
        verbose        => 2,
    );
    isa_ok($box, 'CPAN::Tester::Box');

    my $outbuff;
    eval {
        local *STDERR; # ->run() writes to STDERR, now we capture
        open(*STDERR, '>>', \$outbuff);
        local $SIG{ALRM} = sub { die "Force quit\n" };
        alarm(6 * $box->poll_interval);

        diag("WARNING: This is a slow test (~20 seconds)");
        $box->run();
        fail("Stopped by alarm");
        1;
    } or do {
        is($@, "Force quit\n", "Stopped by alarm");
    };

    is(
        scalar(grep m/^# Overwrite: / => split(m/\n/, $outbuff)),
        3,
        "Found 3 distributions"
    ) or diag("STDERR: ", $outbuff);
    like($outbuff, qr/^# Last\(1W\):/m, "1 week recent");
    like($outbuff, qr/^# Last\(6h\):/m, "6 hour recent");
    is(
        scalar(grep m/^Random output / => split(m/\n/, $outbuff)),
        3,
        "verbose > 1"
    ) or diag("STDERR: ", $outbuff);

    is_deeply(
        $box->handled,
        {
            'A/AB/ABELTJE/Any-Other-1.03.tgz'             => 1,
            'A/AB/ABELTJE/CPAN-Tester-Box-0.01_01.tar.gz' => 1,
            'A/AB/ABELTJE/CPAN-Tester-Box-0.02.tar.gz'    => 1
        },
        "The handled cache is ok"
    ) or diag(explain($box->handled));
}

abeltje_done_testing();
