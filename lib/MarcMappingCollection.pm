package MarcMappingCollection;

use namespace::autoclean;
use Modern::Perl;
use Moose;
use MooseX::StrictConstructor;
use MarcMapping;
use Carp;

has mappings => (
    is => 'ro',
    isa => 'HashRef[MarcMapping]',
    default => sub { return {} }
    );

has record => (
    is => 'rw',
    isa => 'Maybe[Marc::Record]',
    trigger => sub {
        my $self = shift;
        my $record = shift;
        for my $m (keys %{$self->mappings}) {
            $self->mappings->{$m}->record($record);
        }
    }
    );

sub BUILD {
    my $self = shift;
}

#
# Factory function for MARC mappings
#
# marc_mappings (
#     name1 => {
#        map => ['001', {'999', 'a'}]
#     },
#     name2 => {
#        map => ['852', 'c'],
#        append => 1
#     },
#     ...
# )
#
sub marc_mappings {
    my %params = @_;

    my $c = __PACKAGE__->new();

    for my $name (keys %params) {
        my @cfs = ();
        my %fs = ();
        for my $mv ($params{$name}->{map}) {
            if (UNIVERSAL::isa($mv, 'HASH')) {
                for my $sf (keys %$mv) {
                    $fs{$sf} = $mv->{$sf};
                }
            } else {
                push @cfs, $mv;
            }
        }
        my $mm = MarcMapping->new( control_fields => \@cfs, subfields => \%fs );
        if ($params{$name}->{append}) {
            $mm->append_fields(1);
        }
        $c->mappings->{$name} = $mm;
    }
    return $c;
}

sub set {
    my $self = shift;
    my $name = shift;
    my $val = shift;

    croak "No mapping named $name!" unless defined $self->mappings->{$name};

    $self->mappings->{$name}->set($val);
}

__PACKAGE__->meta->make_immutable;

1;
