#! perl -I. -w
use t::Test::abeltje;
use Test::MockObject;

use CPAN::Tester::Box;

(my $recents = Test::MockObject->new)->set_isa('CPAN::Tester::RecentUploads');

my $indent = " " x 12;
my @o_confs = (
    {
        args => { test_report => 1 },
        name => 'o conf => test_report',
    },
    {
        args => {
            test_report => 1,
            make_install_make_command => 'make',
        },
        name => 'o conf => test_report, make_install',
    },
    {
        args => {
            test_report => 1,
            make_install_make_command => 'make',
            mbuild_install_build_command => './Build',
        },
        name => 'o conf => test_report, make_install, mbuild_install',
    },
    {
        args => { },
        name => "no extra options",
    },
    {
        name => "Use default",
        prog => "${indent}CPAN::Shell->o(conf => 'test_report', '1');",
    },

);

for my $test (@o_confs) {
    if (exists($test->{args})) {
        $test->{prog} = $indent . join("\n$indent", map {
            "CPAN::Shell->o(conf => '$_', '$test->{args}{$_}');"
        } sort keys %{$test->{args}});
    }

    my $box = CPAN::Tester::Box->new(
        recent_uploads => $recents,
        (exists($test->{args})
            ? (o_conf => $test->{args})
            : ()
        ),
    );
    isa_ok($box, 'CPAN::Tester::Box');

    my $cmd = $box->_test_command({path => 'A/AB/ABELTJE/Dummy-0.002.tar.gz'});
    is_deeply(
        $cmd,
        [ # WARNING: indentation due to generating software...
            qq/"$^X"/, qq/"-MCPAN"/, qq/"-e"/,
        qq["
${indent}CPAN::HandleConfig->require_myconfig_or_config;
$test->{prog}
${indent}CPAN::Shell->test('A/AB/ABELTJE/Dummy-0.002.tar.gz');
${indent}
        "]
        ],
        $test->{name}
    ) or diag(explain($cmd));
}

abeltje_done_testing();
