#! perl -I. -w
use t::Test::abeltje;

use v5.20.0;
use if $] <  5.036, experimental => 'signatures';
use if $] >= 5.036, feature      => 'signatures';

use CPAN::Tester::RecentUploads;

{
    local *CPAN::Recent::Uploads::Retriever::retrieve = sub {
        my $class = shift;
        my (%args) = @_;
        note("retrieve: ", explain(\%args));
        my $recents = [ ];
        $recents = [
            {
                epoch => time() - 180,
                path  => 'id/A/AB/ABELTJE/CPAN-Tester-Box-0.01.tar.gz',
                type  => 'update',
            },
            {
                epoch => time() - 120,
                path  => 'id/A/AB/ABELTJE/CPAN-Tester-Box-0.01_01.tar.gz',
                type  => 'new',
            },
            {
                epoch => time() - 60,
                path  => 'id/A/AB/ABELTJE/CPAN-Tester-Box-0.02.tar.gz',
                type  => 'new',
            },
        ] if $args{time} eq '1W';
        $recents = [
            {
                epoch => time(),
                path  => 'id/A/AB/ABELTJE/Any-Other-1.03.tgz',
                type  => 'new',
            },
        ] if $args{time} eq '6h';
        use YAML::XS qw< Dump >;
        return Dump({ recent => $recents });
    };

    my $recents = CPAN::Tester::RecentUploads->new(
        mirror => 'http://localhost/cpan',
        interval => '1W',
    );
    isa_ok($recents, 'CPAN::Tester::RecentUploads');

    my $r1 = $recents->get_recent('1W');
    is(scalar(@$r1), 2, "Found 2 (new) recent items");
    isa_ok($r1->[0]{time}, 'DateTime');

    my $r2 = $recents->get_recent('6h');
    is(scalar(@$r2), 1, "Found 1 (new) recent item");
    isa_ok($r1->[0]{time}, 'DateTime');
}

abeltje_done_testing();
