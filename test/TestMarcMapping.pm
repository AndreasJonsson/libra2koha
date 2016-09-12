package TestMarcMapping;

use base qw(Test::Unit::TestCase);

use MarcMapping;
use MARC::Record;
use MARC::File::XML ( BinaryEncoding => 'utf8', RecordFormat => 'NORMARC' );
use Modern::Perl;
use List::MoreUtils qw(pairwise);
use Data::Dumper;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub set_up {
    my $self = shift;
    $self->{record} = MARC::Record->new();
    $self->{mm} = MarcMapping->new(
        control_fields => ['001', '002'],
        subfields => {
            '100' => ['a', 'b', 'c'],
            '101' => ['d', 'e', 'f']
        },
        append_fields => 0
        );
    $self->{mm}->record($self->{record});
}

sub tear_down {
    # clean up after test
}

sub test_get {
    my $self = shift;

    $self->{mm}->set( 'foo' );

    my @res = $self->{mm}->get();

    my @exp = ( 'foo', 'foo', 'foo', 'foo', 'foo', 'foo', 'foo', 'foo' );

    pairwise {
        $self->assert_equals( $a, $b );
    } @exp, @res;

    $self->{mm}->append_fields(1);
    $self->{mm}->reset();

    $self->{mm}->set( 'bar' );

    my $last = $self->{mm}->get();

    @exp = ( 'foo', 'bar', 'foo', 'bar', 'foo', 'bar', 'foo', 'bar', 'foo', 'bar', 'foo', 'bar', 'foo', 'bar', 'foo', 'bar' );
    @res = $self->{mm}->get();

    pairwise {
        $self->assert_equals( $a, $b );
    } @exp, @res;

    $self->assert_equals( 'bar', $last );
}

sub test_set {
    my $self = shift;

    $self->{mm}->set( 'foo' );

    $self->check_control_field( '001', 1, 'foo' );
    $self->check_control_field( '002', 1, 'foo' );

    $self->check_subfield( '100', 'a', 1, 'foo' );
    $self->check_subfield( '100', 'b', 1, 'foo' );
    $self->check_subfield( '100', 'c', 1, 'foo' );
    $self->check_subfield( '101', 'd', 1, 'foo' );
    $self->check_subfield( '101', 'e', 1, 'foo' );
    $self->check_subfield( '101', 'f', 1, 'foo' );

    $self->{mm}->reset();
    $self->{mm}->set( 'bar' );

    $self->check_control_field( '001', 1, 'bar' );
    $self->check_control_field( '002', 1, 'bar' );

    $self->check_subfield( '100', 'a', 1, 'bar' );
    $self->check_subfield( '100', 'b', 1, 'bar' );
    $self->check_subfield( '100', 'c', 1, 'bar' );
    $self->check_subfield( '101', 'd', 1, 'bar' );
    $self->check_subfield( '101', 'e', 1, 'bar' );
    $self->check_subfield( '101', 'f', 1, 'bar' );

}

sub test_set_multi {
    my $self = shift;

    $self->{mm}->set( 'foo', 'bar' );

    $self->check_control_field( '001', 2, 'foo', 'bar' );
    $self->check_control_field( '002', 2, 'foo', 'bar' );

    $self->check_subfield( '100', 'a', 2, 'foo', 'bar' );
    $self->check_subfield( '100', 'b', 2, 'foo', 'bar' );
    $self->check_subfield( '100', 'c', 2, 'foo', 'bar'  );
    $self->check_subfield( '101', 'd', 2, 'foo', 'bar'  );
    $self->check_subfield( '101', 'e', 2, 'foo', 'bar'  );
    $self->check_subfield( '101', 'f', 2, 'foo', 'bar'  );
}

sub test_append {
    my $self = shift;

    $self->{mm}->append_fields(1);

    $self->{mm}->set( 'foo' );

    $self->check_control_field( '001', 1, 'foo' );
    $self->check_control_field( '002', 1, 'foo' );

    $self->check_subfield( '100', 'a', 1, 'foo' );
    $self->check_subfield( '100', 'b', 1, 'foo' );
    $self->check_subfield( '100', 'c', 1, 'foo' );
    $self->check_subfield( '101', 'd', 1, 'foo' );
    $self->check_subfield( '101', 'e', 1, 'foo' );
    $self->check_subfield( '101', 'f', 1, 'foo' );

    $self->{mm}->reset();
    $self->{mm}->set( 'bar' );

    $self->check_control_field( '001', 2, 'foo', 'bar' );
    $self->check_control_field( '002', 2, 'foo', 'bar' );

    $self->check_subfield( '100', 'a', 2, 'foo', 'bar' );
    $self->check_subfield( '100', 'b', 2, 'foo', 'bar' );
    $self->check_subfield( '100', 'c', 2, 'foo', 'bar' );
    $self->check_subfield( '101', 'd', 2, 'foo', 'bar' );
    $self->check_subfield( '101', 'e', 2, 'foo', 'bar' );
    $self->check_subfield( '101', 'f', 2, 'foo', 'bar' );

}

sub test_delete {

    my $self = shift;

    $self->{mm}->set( 'foo' );

    $self->check_control_field( '001', 1, 'foo' );
    $self->check_control_field( '002', 1, 'foo' );

    $self->check_subfield( '100', 'a', 1, 'foo' );
    $self->check_subfield( '100', 'b', 1, 'foo' );
    $self->check_subfield( '100', 'c', 1, 'foo' );
    $self->check_subfield( '101', 'd', 1, 'foo' );
    $self->check_subfield( '101', 'e', 1, 'foo' );
    $self->check_subfield( '101', 'f', 1, 'foo' );

    $self->{mm}->delete();

    $self->check_control_field( '001', 0);
    $self->check_control_field( '002', 0);

    $self->check_subfield( '100', 'a', 0);
    $self->check_subfield( '100', 'b', 0);
    $self->check_subfield( '100', 'c', 0);
    $self->check_subfield( '101', 'd', 0);
    $self->check_subfield( '101', 'e', 0);
    $self->check_subfield( '101', 'f', 0);

    my @field100 = $self->{record}->field( '100' );
    my @field101 = $self->{record}->field( '101' );

    $self->assert_equals(0, 0 + @field100);
    $self->assert_equals(0, 0 + @field101);

}

sub check_control_field {
    my $self = shift;
    my $tag = shift;
    my $length = shift;
    my @val = (@_);

    my @fields = $self->{record}->field( $tag );

    $self->assert_equals($length, 0 + @fields);

    pairwise {
        $self->assert( defined($a) );
        $self->assert( defined($b) );
        $self->assert_equals($b->data(), $a);
    } @val, @fields;
}

sub check_subfield {
    my $self = shift;
    my $tag = shift;
    my $subtag = shift;
    my $length = shift;
    my @val = @_;

    my @subfields = ();
    for my $field ($self->{record}->field( $tag )) {
        push @subfields, $field->subfield( $subtag );
    }

    $self->assert_equals( $length, 0 + @subfields );

    pairwise {
        $self->assert_equals( $a, $b );
    } @val, @subfields;
}

1;
