package MarcMapping;

use namespace::autoclean;
use Modern::Perl;
use Moose;
use MooseX::StrictConstructor;
use Carp;

has record => (
    is => 'rw',
    isa => 'Maybe[Marc::Record]'
    );

has control_fields => (
    is => 'rw',
    isa => 'ArrayRef[Str]'
    );

has subfields => (
    is => 'rw',
    isa => 'HashRef[ArrayRef[Str]]';
    );

has append_fields => (
    is => 'rw',
    isa => 'Bool',
    default => '0'
    );

sub BUILD {
    my $self = shift;
}

sub mm_sf {
    my ($field, $sub) = @_;
    return MarcMapping->new(subfields => { $field => [ $sub ] });
}


sub set {
    my $self = shift;
    my $n = +@_;

    croak "No record bound!" unless $self->record;

    for my $cf ($self->control_fields) {
        my $cfn = 0;
        if (!$self->append_fields) {
            for my $field ($self->record->field($cf)) {
                if ($cfn >= $n) {
                    croak "Not enough values given for control field $cf"
                }
                $field->update($_[$cfn]);
                $cfn++;
            }
        }
        for (my $i = $cfn; $i < $n; $i++) {
            my $field = Marc::Field->new($cf, $@_[i]);
            $self->record->append_fields( $field )
        }
    }

    for my $f (keys %{$self->subfields}) {
        my $nf = 0;
        if (!$self->append_fields) {
            for my $field ($self->record->field($f)) {
                if ($nf >= $n) {
                    croak "Not enough values given for field $f";
                }
                $field->update( $self->subfields->{$f} => $_[$nf] );
                $nf++;
            }
        }
        for (my $i = $nf; $i < $n; $i++) {
            my $field = Marc::Field->new($f, ' ', ' ',
                                         $self->subfields->{$f} => @_[$i]);
            $self->record->append_fields( $field );
        }
}

sub get {
    my $self = shift;

    croak "No record bound!" unless $self->record;

    my @ret = ();

    for my $cf ($self->control_fields) {
        push @ret, $self->record->field( $cf );
    }

    for my $f (keys %{$sef->subfields}) {
        push @ret, $self->record->subfield($f, $self->subfields->{$f});
    }

    return @ret if wantarray;
    return $ret[$#ret];
}

sub delete {
    my $self = shift;

    croak "No record bound!" unless $self->record;

    for my $cf (@{$self->control_fields}) {
        $self->record->delete_fields( $self->record->field( $cf ) );
    }

    for my $f (keys %{$self->subfields}) {
        map {
            $_->delete_subfield( code => $self->subfields->{$f} );
            if (0 + $_->subfields == 0) {
                $self->record->delete_fields( $_ );
            }
        } $self->record->field( $f );
    }
}

__PACKAGE__->meta->make_immutable;

1;
