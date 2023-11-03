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
