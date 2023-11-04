#! perl -w
use strict;
use v5.20.0;

use ExtUtils::MakeMaker::CPANfile;

WriteMakefile(
    NAME             => 'CPAN::Tester::Box',
    VERSION_FROM     => 'lib/CPAN/Tester/Box.pm',
    ABSTRACT_FROM    => 'lib/CPAN/Tester/Box.pm',
    AUTHOR           => 'Abe Timmerman <abeltje@cpan.og>',
    LICENSE          => 'perl_5',
    MIN_PERL_VERSION => 5.20.0,

    # Dependencies managed in cpanfile
    EXE_FILES => [qw< bin/cpan-tester-box >],

    META_MERGE => {
        'meta-spec' => { version => 2 },
        'resources' => {
            repository => {
                type => 'git',
                url  => 'https://github.com/abeltje/CPAN-Test-Box.git',
                web  => 'https://github.com/abeltje/CPAN-Test-Box',
            },
            bugtracker => {
                web => 'https://github.com/abeltje/CPAN-Test-Box/issues',
            },
        },
    },
);

package MY;

sub test {
    my $self = shift;
    my $orig = $self->SUPER::test(@_);

    $orig .= <<"EOM";

XTEST_FILES = xt/*.t
xtest ::
EOM

    my $varpfx = $^O eq 'MSWin32' ? '$$' : '\$$';
    $orig .= "\t"
           . qq{\$(FULLPERLRUN) "-e" "my ${varpfx}sw=q[-wl]; }
           . qq{${varpfx}sw .= q[v] if \$(TEST_VERBOSE); }
           . qq{system qq[prove ${varpfx}sw \$(XTEST_FILES)]"};

    return $orig;
}
1;
