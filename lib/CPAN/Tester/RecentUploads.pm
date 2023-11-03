package CPAN::Tester::RecentUploads;
use Moo;
use v5.20.0;
use if $] <  5.036, experimental => 'signatures';
use if $] >= 5.036, feature      => 'signatures';
use Carp;

our $VERSION = '0.01';

use CPAN::Recent::Uploads::Retriever;
use DateTime;
use YAML::XS qw< Load >;

=head1 NAME

CPAN::Testers::RecentUploads - Wrapper around L<CPAN::Recent::Uploads::Retriever>.

=head1 ATTRIBUTES

=head2 mirror

This is the URI for the mirror to use to determine recent uploads. This is an
B<InstanceOf> either L<URI::http> or L<URI::https>, but strings are coerced into
a L<URI> instance.

I<Default>: B<http://www.cpan.org>

=head2 interval

This is one of: B<1h>, B<6h>, B<1d>, B<1W>, B<1M>, B<1Q> or B<1Y>. See
L<CPAN::Recent::Uploads> for details.

I<Default>: B<1W>

=cut

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

my $_ext_re = qr{ \. (?: tar\.gz | tar\.bz2 | tgz | zip ) }x;

=head1 SYNOPSIS

    my $recents = CPAN::Tester::RecentUploads->new(
        mirror => 'https://www.cpan.org',
    );

=head1 DESCRIPTION

=head2 $ru->get_recent($interval)

=cut

sub get_recent ($self, $interval) {
    $interval //= $self->interval;

    my $yaml = CPAN::Recent::Uploads::Retriever->retrieve(
        time   => $interval,
        mirror => $self->mirror->as_string,
    );
    my $recent;
    eval { $recent = Load($yaml); 1 } or confess("Cannot unyaml: $!");

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
        and $_->{path} !~ m{ /perl6 }xi
    } @{$recent->{recent}} ];

    return $list;
}

use namespace::autoclean;
1;

=head1 COPYRIGHT

E<copy> MMXXIII - Abe Timmerman <abeltje@cpan.org>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
