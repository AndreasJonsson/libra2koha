
package TestMarcFieldHolder;

use base qw(Test::Unit::TestCase);

use MarcUtil::MarcFieldHolder;
use MARC::Record;
use MARC::File::XML ( BinaryEncoding => 'utf8', RecordFormat => 'NORMARC' );
use Modern::Perl;

use Data::Dumper;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub set_up {
    my $self = shift;
    $self->{record} = MARC::Record->new();
}

sub tear_down {
    # clean up after test
}

sub test_set {
    my $self = shift;

    my $mfh = MarcUtil::MarcFieldHolder->new(
        record => $self->{record},
        tag => '100'
        );

    $mfh->set_subfield('a', 'foo');

    my @fields = $self->{record}->field('100');

    $self->assert_equals(1, (0 + @fields));
    $self->assert_equals('foo', $fields[0]->subfield('a'));

    $mfh->set_subfield('b', 'bar');

    @fields = $self->{record}->field('100');

    $self->assert_equals(1, (0 + @fields));
    $self->assert_equals('foo', $fields[0]->subfield('a'));
    $self->assert_equals('bar', $fields[0]->subfield('b'));

    $mfh->set_subfield('a', 'baz');

    @fields = $self->{record}->field('100');

    $self->assert_equals(1, (0 + @fields));
    $self->assert_equals('baz', $fields[0]->subfield('a'));
    $self->assert_equals('bar', $fields[0]->subfield('b'));

}

sub test_initated_field {
    my $self = shift;

    my $field = new MARC::Field('100', ' ', ' ', a => 'initial');
    $self->{record}->add_fields( $field );

    my $mfh = MarcUtil::MarcFieldHolder->new(
        record => $self->{record},
        tag => '100',
        field => $field
        );

    my @fields = $self->{record}->field('100');
    $self->assert_equals(1, (0 + @fields));
    $self->assert_equals('initial', $fields[0]->subfield('a'));

    $mfh->set_subfield('a', 'foo');

    @fields = $self->{record}->field('100');
    $self->assert_equals(1, (0 + @fields));
    $self->assert_equals('foo', $fields[0]->subfield('a'));
}



1;
