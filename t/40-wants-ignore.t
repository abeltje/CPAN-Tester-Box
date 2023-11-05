#! perl -I. -w
use t::Test::abeltje;
use Test::MockObject;

use CPAN::Tester::Box;

my @ignore = (
    {
        item => { path => 'D/DU/DUMMY/Some-Dist-1.00.tar.gz' },
        skip => [qw< \bDUMMY\b Some-Other-Dist\b >],
        test => "\\bDUMMY\\b",
    },
    {
        item => { path => 'D/DU/DUMMY/Some-Dist-1.00.tar.gz' },
        skip => [qw< \bDUMMY\b Some-Dist\b >],
        test => "\\bDUMMY\\b Some-Dist\\b",
    },
    {
        item => { path => 'D/DU/DUMMYTOO/Some-Dist-1.00.tar.gz' },
        skip => [qw! \bDUMMY\b Some-Dist-(?=\d) !],
        test => "Some-Dist-(?=\\d)",
    },
);

(my $recents = Test::MockObject->new)->set_isa('CPAN::Tester::RecentUploads');
for my $test (@ignore) {
    my $box = CPAN::Tester::Box->new(
        recent_uploads => $recents,
        ignore         => $test->{skip},
    );
    isa_ok($box, 'CPAN::Tester::Box');

    my $ip = $box->wants_ignore($test->{item});
    is("@$ip", $test->{test}, "SKIP: @{$test->{skip}}") or diag("@$ip");
}

abeltje_done_testing();
