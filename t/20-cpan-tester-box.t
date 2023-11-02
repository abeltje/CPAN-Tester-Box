#! perl -w
use strict;

use Test::More;
use Test::MockObject;

use CPAN::Tester::Box;

{
    (my $recent_uploads = Test::MockObject->new)->set_isa('CPAN::Tester::RecentUploads');
    $recent_uploads->set_always(interval => '1W');
    $recent_uploads->set_series(
        get_recent => [
            { epoch => time() - 120, path => 'A/AB/ABELTJE/CPAN-Tester-Box-0.01_01.tar.gz' },
            { epoch => time() - 60, path  => 'A/AB/ABELTJE/CPAN-Tester-Box-0.02.tar.gz' },
        ],
        [
            { epoch => time(), path => 'A/AB/ABELTJE/Any-Other-1.03.tgz' },
        ],
        [ ],
    );

    my $box = CPAN::Tester::Box->new(
        recent_uploads => $recent_uploads,
        poll_interval => 3,
    );
    isa_ok($box, 'CPAN::Tester::Box');

    eval {
        local $SIG{ALRM} = sub { die "Force quit\n" };
        alarm(4 * $box->poll_interval);
        $box->run();
        alarm(0);
        1;
    } or do {
        is($@, "Force quit\n", "Stopped by alarm");
    };
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

done_testing();
