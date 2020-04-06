package KodalarnaRecordProc;

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
	    $f003 = MARC::Field->new('003', 'KodalarnaImport');
	    $record->insert_fields_ordered($f003);
	} else {
	    $f003->data('KodalarnaImport');
	}
    }

    my @branchcodes = map { if (/^1111/) { 'fal' } elsif (/^9999/) { 'bor'} else { 'unknown' } } $mmc->get('items.barcode');

    $mmc->set('items.homebranch', @branchcodes);
    $mmc->set('items.holdingbranch', @branchcodes);

    $mmc->set('items.cn_source', map {'SAB'} @branchcodes );

    my @callnumbers = map { $self->{bibextra_sth}->execute($_); $self->{bibextra_sth}->fetchrow } $mmc->get('items.barcode');
    $mmc->set('items.itemcallnumber', @callnumbers);

    my @itypes = $mmc->get('items.itype');

    my @notforloan = map { $_ eq 'REF' || $_ eq 'COURSEREF' ? 1 : 0 } @itypes;
    $mmc->set('items.notforloan', @notforloan);

    my $field = $record->field('998');
    if (defined $field && $field->subfield('d')) {
	my $v = $field->subfield('d');
	my $itype = '';
	if ($v eq 'j') {
	    $itype = 'CD';
	} elsif ($v eq 'z') {
	    $itype = 'EBOOK';
	} elsif ($v eq 'f') {
	    $itype = 'FILM';
	} elsif ($v eq 's') {
	    $itype = 'BOOK';
	}
	$mmc->set("biblioitemtype", $itype);
    }
    
    $record->delete_fields($record->field('945'));
    #$record->delete_fields($record->field('907'));

    return $record;
}

1;
