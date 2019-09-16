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
	my $loc = {};
	for (my $i = 0; $i < scalar(@$columns); $i++)  {
	    add_col($columns, $row, $loc, $i);
	}
	my $key = $row->[0];
	if ($key =~ /^(?:[(]?blank[)]?|(?: ?))$/i) {
	    $key = '';
	}
	$locs{$key} = $loc;
    }    
    
    return bless {
	opt => $opt,
	csv => $csv,
	locs => \%locs
    };

}

sub add_col {
    my ($columns, $row, $loc, $i) = @_;

    my $col = $columns->[$i];

    if ($col =~ /(koha)|(loc)|(local)|(location)|(local_?shelf)/i) {
	$loc->{localshelf} = $row->[$i];
    } elsif ($col =~ /callnumber\.src/) {
	my @src_callnumbers = split '\s*,\s*', $col;
	$loc->{src_callnumbers} = \@src_callnumbers;
    } elsif ($col =~ /(ccode)|(collection.?code)/i) {
	$loc->{ccode} = $row->[$i];
    } elsif ($col =~ /(exemplartyp)|(itemtype)|(itype)/i) {
	$loc->{itemtype} = $row->[$i];
    } elsif ($i != 0) {
	warn "Unmapped column: " . $col;
    }
}

sub check {
    my $v = shift;
    return defined($v) && !($v =~ /^\s*Raderas\s*$/i);
}

sub match {
    my ($loc, $item) = @_;

    if (defined($loc->{src_callnumber})) {
    }
    return 1;
}

sub process {
    my ($self, $mmc, $item) = @_;

    if (defined($item->{LocalShelf})) {
	my $l = $item->{LocalShelf};
	if ($l =~ m/^ ?$/) {
	    $l = '';
	}
	my $loc = $self->{locs}->{$l};
	if (defined($loc) && match($loc, $item)) {
	    if (check($loc->{localshelf})) {
		$mmc->set('items.location', $loc->{localshelf});
	    }
	    if (check($loc->{ccode})) {
		$mmc->set('items.ccode', $loc->{ccode});
	    }
	    if (check($loc->{itemtype})) {
		$mmc->set('items.itype', $loc->{itemtype});
		if (!$mmc->get('biblioitemtype')) {
		    $mmc->set('biblioitemtype', $loc->{itemtype});
		}
	    }
	}
    }
}

1;
