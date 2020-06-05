package KosodertornRecordProc;

import RecordUtils;
use utf8;
use DateTime;
use DateTime::Format::Builder;

sub new {
    my ($class, $opt, $config_tables, $dbh, $bibextra_sth) = @_;

    my $fh;

    my $date_parser = DateTime::Format::Builder->new()->parser( regex => qr/^(\d{2})-?(\d\d)-?(\d\d)/,
								params => [qw(year month day)] );
    
    open $fh, ">:utf8", $opt->outputdir . "/icodes.sql";

    return bless {
	opt => $opt,
	branchcodes => $config_tables->{branchcodes},
	dbh => $dbh,
	bibextra_sth => $bibextra_sth,
	f001c => 0,
	icodefh => $fh,
	dp => $date_parser
    };
}

sub genf001 {
    my $self = shift;

    my $n = $self->{f001c}++;

    return sprintf "%010d", $n;
}

my %icodes = (
    '5' => 'Granskad 2015 (SUS)',
    '6'	=> 'Granskad 2016 (SUS)',
    '7'	=> 'Granskad 2017',
    '9' => 'Granskad 2019',
    'i' => 'Gallras ej',
    'n' => 'SUPPRESS'
    );

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

    copy($mmc, { m => 'sierra_dateaccessioned', f => sub {
	if (!defined($_[0])) {
	    return undef;
	}
	my $d;
	eval { $d = $self->{dp}->parse_datetime($_[0]); };
	if (!defined $d) {
	    return undef;
	}
	if ($d->year < 100) {
	    $d = $d->add(years => 2000);
	}
	return $d->strftime('%F');
		 } }, 'items.dateaccessioned');
    
    my @icodes = $mmc->get('sierra_icode');
    my @sysnumbers = $mmc->get('sierra_sysnumber');
    my @notes = map { message($_) } $mmc->get('items.itemnotes_nonpublic');

    my $hasicode = 0;
    for (my $i = 0; $i < scalar(@sysnumbers); $i++) {
	if (defined $icodes{$icodes[$i]}) {
	    my $icode = $icodes{$icodes[$i]};
	    $notes[i] = $icode . (defined $notes[i] ? "\n" . $notes[i] : '');
	    $hasicode = 1;
	}
    }

    $mmc->set('items.itemnotes_nonpublic', @notes);

    $mmc->set('items.itemnotes', map { opacmsg($_) } $mmc->get('items.itemnotes'));

    #my $n = 1;
    
    $mmc->set('items.copynumber', sub { return undef; });
    
    return $record;
}


sub message {
    my $m = shift;

    return ($m eq 'f' ? 'ON THE FLY' : undef);
}

my %opacmsgs = (
    'b' => 'DAY LOAN',
    'f' => 'COURSE MTRL',
    'g'	=> 'REFERENCE BOOK',
    'i' => 'ASK THE LIBRARY',
    'k' => 'COURSE BOOK'
    );

sub opacmsg {
    my $m = shift;

    return $opacmsgs{$m};
}

1;
