package TupleColumn;

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(parse_tuple extract_tuple encode_tuple);
@EXPORT_OK   = qw();


use Modern::Perl;
use Data::Dumper;

sub parse_tuple {
    my $s = shift;

    if ($s =~ /^\s*\(\s*(?:(?:\d+)\s*(?:,\s*(?:\d+)\s*)*)?\)\s*$/) {
	my @res = ();
	while ($s =~ /\d+/gp) {
	    push @res, int(${^MATCH});
	}
	return \@res;
    }

    return undef;
}

sub extract_tuple {
    my ($a, $t) = @_;

    my @r = ();
    for my $i (@$t) {
	push @r, $a->[$i];
    }

    return \@r;
}

sub encode_tuple {
    my $t = shift;

    my $s = "(";
    my $f = 1;
    for my $x (@$t) {
	if ($f) {
	    $f = 0;
	} else {
	    $s .= ', ';
	}
	$s .= $x;
    }
    return $s . ")";
}

1;
