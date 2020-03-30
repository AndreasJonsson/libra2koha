package MarcRecordGenerator;

$VERSION     = 1.00;
@ISA         = qw(RecordGenerator Exporter);
@EXPORT      = qw();
@EXPORT_OK   = qw();

use strict;
use RecordGenerator;
use Exporter;

use MARC::File::USMARC ;
use MARC::File::XML ( RecordFormat => 'USMARC' );
use MARC::Batch;
use MARC::Charset qw( marc8_to_utf8 );
use Unicode::Normalize qw(NFC);

sub init {
    my $self = shift;

    $self->reset();
}

sub nextfile {
    my $self = shift;

    my $file = $self->SUPER::nextfile;
    if (!defined($file)) {
	return 0;
    }
    my $batch;
    if ($self->{opt}->xml_input) {
	$batch = MARC::Batch->new( 'XML', $file );
    } else {
	open FH, "<:bytes", $file or die "Could not open '$file': $!";
	$batch = MARC::File::USMARC->in( \*FH );
    }

    $self->{batch} = $batch;

    return 1;
}

sub next {
    my $self = shift;
    my $record;
    while (1) {
	if (!defined($self->{batch})) {
	    if (!$self->nextfile) {
		return undef;
	    }
	}

	$record = $self->{batch}->next();

	if (defined $record) {
	    if ($record->encoding() eq 'MARC-8') {
		convert_record($record);
	    }

	    return $record;
	} else {
	    $self->close;
	}
    }
}

sub close {
    my $self = shift;

    unless ($self->{opt}->xml_input) {
	if (defined($self->{batch})) {
	    $self->{batch}->close();
	}
    }
    $self->{batch} = undef;
}

sub convert_record {
    my $record = shift;

    #print STDERR "Converting record\n";
    my @warnings = ();
    my $fieldtag;
    my $subfield;
    
    local $SIG{__WARN__} = sub {
	my $warning = shift;
	if (! ($warning =~ /^Use of uninitialized value in subroutine entry at/)) {
	    $warning = $fieldtag . ($subfield eq '' ? '' : '$' . $subfield) . ': ' . $warning;
	    $warning =~ s/[\x00-\x1f\x80-\xff]//g;
	    for (my $i = 0 ; $i < length($warning); $i++) {
		print STDERR (ord(substr($warning, $i, 1)), ",");
	    }
	    push @warnings, $warning;
	}
    };
    
    for my $field ($record->fields()) {
	$fieldtag = $field->tag();
	$subfield = '';
	if (!$field->is_control_field()) {
	    #print STDERR "Converting field $field->{_tag}\n";
	    if (defined($field->{_subfields})) {
		for (my $i = 1; $i < @{$field->{_subfields}}; $i += 2) {
		    $subfield = $field->{_subfields}->[$i - 1];
		    $field->{_subfields}->[$i] = NFC(marc8_to_utf8($field->{_subfields}->[$i], 1));
		}
	    }
	}
    }
    $record->encoding('UTF-8');
    for my $warning (@warnings) {
	$record->add_fields([ 963, " ", " ", a => $warning ]);
    }
}

1;
