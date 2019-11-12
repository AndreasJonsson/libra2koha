package ArbogaBranchcodes;

sub new {
    my ($class, $opt) = @_;

    return bless {
	opt => $opt
    };
    
}

sub skolan {
    my $loc = shift;
    my $branch = shift;

    if ($loc eq 'Skolan') {
	return 'ARBSKOLDEP';
    }

    return $branch;
}

sub ccode {
    my $ccode = shift;
    my $branch = shift;

    if ($ccode eq 'KONSTSAMLINGEN' || $ccode eq 'FOTOSAMLINGEN') {
	return 'ARBKONST';
    } elsif ($ccode eq 'ARBOGASAMLINGEN') {
	return 'ARBSAML';
    }

    return $branch;
}

sub _process {
    my ($a, $b, $f) = @_;
    if (scalar(@$a) == scalar(@$b)) {
	for (my $i = 0; $i < scalar(@$a); $i++) {
	    $a->[$i] = $f->($b->[$i], $a->[$i]);
	}
    }
}

sub process {
    my ($self, $mmc, $record) = @_;

    my @homebranches = $mmc->get('items.homebranch');
    my @holdingbranches = $mmc->get('items.holdingbranch');
    my @locs = $mmc->get('items.location');
    my @ccodes = $mmc->get('items.ccode');

    _process(\@homebranches, \@locs, \&skolan);
    _process(\@holdingbranches, \@locs, \&skolan);
    _process(\@homebranches, \@ccodes, \&ccode);
    _process(\@holdingbranches, \@ccodes, \&ccode);

    $mmc->set('items.homebranch', @homebranches);
    $mmc->set('items.holdingbranch', @holdingbranches);
}

1;
