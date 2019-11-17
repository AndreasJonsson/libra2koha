package CsvLocProcessor;

use Text::CSV;

sub new {
    my ($class, $opt) = @_;

    my $csv = my $csv = Text::CSV->new;
    my $fh;
    open $fh, "<:encoding(utf8)", ($opt->config . '/Loc.csv');

    my $columns = $csv->getline( $fh );
    $csv->column_names( @$columns );

    my %locs = ();

    while (my $row = $csv->getline($fh)) {
	my $loc = { key => 0 };
	for (my $i = 0; $i < scalar(@$columns); $i++)  {
	    add_col($columns, $row, $loc, $i);
	}
	my $key = $loc->{key};
	if ($key =~ /^(?:[(]?blank[)]?|(?: ?))$/i) {
	    $key = '';
	}
	$key = lc trim($key);
	if (defined $locs{$key}) {
	    push @{$locs{$key}}, $loc;
	} else {
	    $locs{$key} = [$loc];
	}
    }    
    
    return bless {
	opt => $opt,
	csv => $csv,
	locs => \%locs
    };

}

sub trim {
    my $_ = shift;
    s/^\s*(.*)\s*$/$1/;
    return $_;
}

sub add_col {
    my ($columns, $row, $loc, $i) = @_;

    my $col = trim($columns->[$i]);

    if ($col =~ /(koha)|(loc)|(local)|(location)|(local_?shelf)/i) {
	$loc->{localshelf} = trim($row->[$i]);
    } elsif ($col =~ /callnumber\.src/) {
	my @src_callnumbers = map {trim($_)} split '\s*,\s*', $row->[$i], -1;
	$loc->{src_callnumbers} = \@src_callnumbers;
    } elsif ($col =~ /ccode\.src/) {
	$loc->{src_ccode} = trim($row->[$i]);
    } elsif ($col =~ /(ccode)|(collection.?code)/i) {
	$loc->{ccode} = trim($row->[$i]);
    } elsif ($col =~ /(exemplartyp)|(itemtype)|(itype)/i) {
	$loc->{itemtype} = trim($row->[$i]);
    } elsif ($col =~ /key/i) {
	$loc->{key} = trim($row->[$i]);
    } elsif ($i != 0) {
	warn "Unmapped column: " . $col;
    }

    if (!defined $loc->{key}) {
	$loc->{key} = trim($row->[0]);
    }
}

sub check {
    my $v = shift;
    return defined($v) && !($v =~ /^\s*Raderas\s*$/i);
}

sub match {
    my ($loc, $item, $mmc) = @_;

    if (defined($loc->{src_callnumbers}) && scalar(@{$loc->{src_callnumbers}}) > 0) {
	my $cn0 = $mmc->get('call_number');
	for my $cn (@{$loc->{src_callnumbers}}) {
	    if (lc $cn0 eq lc $cn) {
		return 1;
	    }
	}
	return 0;
    }

    if (defined($loc->{src_ccode}) && $loc->{src_ccode} ne '') {
	my $ccode = $mmc->get('items.ccode');
	if (lc trim($ccode) eq lc $loc->{src_ccode}) {
	    return 1;
	}
	return 0;
    }

    return 1;
}

sub process {
    my ($self, $mmc, $item) = @_;

    if (defined($item->{LocalShelf})) {
	my $l = trim($item->{LocalShelf});
	if ($l =~ m/^ ?$/) {
	    $l = '';
	}
	$l = lc $l;
	my $matched = 0;
	for my $loc (@{$self->{locs}->{$l}}) {
	    if (defined($loc) && match($loc, $item, $mmc)) {
		if (check($loc->{localshelf})) {
		    $mmc->set('items.location', trim($loc->{localshelf}));
		}
		if (check($loc->{ccode})) {
		    $mmc->set('items.ccode', trim($loc->{ccode}));
		}
		if (check($loc->{itemtype})) {
		    $mmc->set('items.itype', trim($loc->{itemtype}));
		    if (!$mmc->get('biblioitemtype')) {
			$mmc->set('biblioitemtype', trim($loc->{itemtype}));
		    }
		}
		$matched = 1;
		last;
	    }
	}
	if (!$matched && $l != '') {
	    print STDERR "No match for location: '$l'\n";
	}
    }
}

1;
