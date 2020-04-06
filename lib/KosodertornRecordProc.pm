package KosodertornRecordProc;

import RecordUtils;
use utf8;

sub new {
    my ($class, $opt, $config_tables, $dbh, $bibextra_sth) = @_;
    return bless {
	opt => $opt,
	branchcodes => $config_tables->{branchcodes},
	dbh => $dbh,
	bibextra_sth => $bibextra_sth,
	f001c => 0
	    
    };
}

sub genf001 {
    my $self = shift;

    my $n = $self->{f001c}++;

    return sprintf "%010d", $n;
}

sub process {
    my ($self, $mmc, $record) = @_;

    if (!$mmc->get("huvudspråk")) {
	my $field = $record->field('998');
	if (defined $field && $field->subfield('f')) {
	    $mmc->set("huvudspråk", $field->subfield('f'));
	}
    }

    my $f001 = $record->field('001');
    if (!defined $f001) {
	my $f003 = $record->field('003');
	$f001 = MARC::Field->new('001', $self->genf001);
	$record->insert_fields_ordered($f001);
	if (!defined $f003) {
	    $f003 = MARC::Field->new('003', 'KosodertornImport');
	    $record->insert_fields_ordered($f003);
	} else {
	    $f003->data('KosodertornImport');
	}
    }

    $mmc->set('items.homebranch', @branchcodes);
    $mmc->set('items.holdingbranch', @branchcodes);

    
    return $record;
}

1;
