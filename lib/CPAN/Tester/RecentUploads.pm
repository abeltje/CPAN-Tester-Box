package CPAN::Tester::RecentUploads;
use Moo;
use v5.36.1;

our $VERSION = '0.01';

use URI;
use Types::Standard qw< Enum InstanceOf >;
has mirror => (
    is      => 'ro',
    isa     => InstanceOf([ 'URI::http', 'URI::https' ]),
    coerce  => sub { return URI->new($_[0]); },
    default => 'http://www.cpan.org'
);
has interval => (
    is      => 'ro',
    isa     => Enum [qw< 1h 6h 1d 1W 1M 1Q 1Y >],
    default => '1W'
);

use CPAN::Recent::Uploads::Retriever;
use DateTime;
use YAML::XS qw< Load >;

# implementation
my $_ext_re = qr{ \. (?: tar\.gz | tar\.bz2 | tgz | zip ) }x;

sub get_recent {
    my $self = shift;
    my ($interval) = @_;
    $interval //= $self->interval;

    my $yaml = CPAN::Recent::Uploads::Retriever->retrieve(
        time   => $interval,
        mirror => $self->mirror->as_string,
    );
    my $recent;
    eval { $recent = Load($yaml); 1 } or die "Cannot unyaml: $!";

    my $list = [ map {
        (my $path = $_->{path}) =~ s{^ id/ }{}x;
        {
            path  => $path,
            epoch => $_->{epoch},
            time  => DateTime->from_epoch(
                epoch => $_->{epoch},
                ($ENV{TZ} ? (time_zone => $ENV{TZ}) : ()),
            ),
        }
    }sort {
        $a->{epoch} <=> $b->{epoch}
    } grep {
            $_->{path} =~ m{^ id/[A-Z]/[A-Z]{2}/ .+ $_ext_re $}x
        and $_->{type} eq 'new'
        and $_->{path} !~ m{ /perl-5\. }x
    } @{$recent->{recent}} ];

    return $list;
}

use namespace::autoclean;
1;
