package EmbeddedItemsProc;

sub new {
    my ($class, $opt) = @_;
    return bless {};
}

sub process {
    my ($self, $mmc, $record) = @_;


    if ($opt->items_format = 'sierra') {
	do_sierra_items($mmc, {}, {});
    }
}

sub do_sierra_items {
    my $mmc = shift;
    my $bibextra = shift;
    my $loc = shift;

    my @sysnumbers = $mmc->get('sierra_sysnumber');
    if ($opt->separate_items) {
	map { $mmc->new_item($_) } @sysnumbers;
    }
    my @branches = map { $opt->default_branchcode } @sysnumbers;

    $mmc->set('items.homebranch', @branches);
    $mmc->set('items.holdingbranch', @branches);
    
    copy($mmc, 'sierra_barcode', 'items.barcode');
    copy($mmc, 'sierra_created', 'items.dateaccessioned');
    copy($mmc, 'sierra_total_checkouts', 'items.issues');
    copy($mmc, 'sierra_total_renewals', 'items.renewals');
    copy($mmc, { m => 'sierra_price', f => sub {
	if (!defined($_[0])) {
	    return;
	}
	$_[0] =~ /^(\d*)/; return $1; } }, 'items.price');
    copy($mmc, 'sierra_note', 'items.itemnotes_nonpublic');
    copy($mmc, 'sierra_message', 'items.itemnotes');
    copy($mmc, 'sierra_call_number', 'items.itemcallnumber');
    copy($mmc, 'sierra_volume', 'items.enumchron');
    copy($mmc, 'sierra_copy_number', 'items.copynumber');

    copy($mmc, { m => 'sierra_restricted', f => sub {
	if (!defined($_[0])) {
	    return
	}
	my %map = (
	    'e' => 1,
	    'l' => 2,
	    'o' => 3
	    );
	return $map{$_[0]};
	
		 }
	 }, 'items.restricted');

    copy($mmc, { m => 'sierra_status', f => sub {
	if (!defined($_[0])) {
	    return
	}
	my %map = (
	    'r' => 1
	    );
	return $map{$_[0]};
		 }
	 }, 'items.damaged');

    copy($mmc, { m => 'sierra_status', f => sub {
	if (!defined($_[0])) {
	    return
	}
	my %map = (
	    'm' => 4,
	    '$' => 3,
	    'n' => 2,
	    'k' => 1
	    );
	return $map{$_[0]};
	 }
    }, 'items.itemlost');

    copy($mmc, { m => 'sierra_status', f => sub {
	if (!defined($_[0])) {
	    return
	}
	if ($_ eq 'u') { return '2019-05-28'; } else { return undef; } } }, 'items.onloan');

    copy($mmc, { m => 'sierra_itemtype', f => sub {
	if (!defined($_[0])) {
	    return
	}
	my %map = (
	    11 => 'BILD',
	    2 => 'BOK',
	    7 => 'FILM',
	    16 => 'FL-MEDIER',
	    18 => 'SAK',
	    20 => 'MS',
	    6 => 'ATLAS',
	    13 => 'ML-MEDIER',
	    10 => 'CD',
	    4 => 'MUS-MS',
	    3 => 'NOT',
	    15 => 'PAKET',
	    9 => 'TAL',
	    1 => 'TEXT',
	    14 => 'PER',
	    0 => 'NONE'
	    );
	return $map{$_[0]};
    } }, 'items.itype');

    copy($mmc, { m =>'sierra_location', f => sub {
	if (!defined($_[0])) {
	    return
	}
	my %map = (
	    'a' => 'Arkiv',
	    'arark' => 'Arkiv',
	    'arref' => 'Arkiv',
	    'b' => 'ingen',
	    'brrar' => 'Rariteter',
	    'brref' => 'Referens',
	    'brtid' => 'Per',
	    'buba' => 'Barn',
	    'bucd' => 'CD',
	    'bumag' => 'mag1',
	    'buny' => 'öppen',
	    'buork' => 'Orkester',
	    'bupj' => 'PjäsHem',
	    'e' => 'EMS',
	    'errar' => 'EMSRa',
	    'erref' => 'EMSRe',
	    'ertid' => 'EMSPe',
	    'eubib' => 'EMS',
	    'eucd' => 'EMSCD',
	    's' => 'SVA',
	    'srref' => 'SVA'
	);
	return $map{$_[0]};
    } }, 'items.location');

    if (defined $bibextra->{'collection_code'}) {
	$mmc->set('items.ccode', $bibextra->{'collection_code'});
    }

    if (defined $bibextra->{'itype'}) {
	$mmc->set('items.itype', $bibextra->{'itype'});
    }

}


1;

