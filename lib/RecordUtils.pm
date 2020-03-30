package RecordUtils;

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(copy copy_merge copy_merge_with_fallback cmp_records cmp_field trim);
@EXPORT_OK   = qw();

use Modern::Perl;

sub trim {
    my $s = shift;
    $s =~ s/^\s*(.*?)\s*$/$1/s;
    return $s;
}

sub copy {
    my ($mc, $from, $to) = @_;

    if (ref($from) eq 'HASH') {
	my $mapping = $from->{m};
	my @values = $mc->get($mapping);
	$mc->set($to, map {$from->{f}->($_)} @values);
    } else {
	$mc->set($to, $mc->get($from));
    }
}

sub copy_merge {
    my ($mc, $from, $to, $fallback) = @_;

    my @f = ();
    for my $f0 (@$from) {
	my @f0;
	if (ref($f0) eq 'HASH') {
	    @f0 = map {$f0->{f}->($_)} @{$mc->get($f0->{m})};
        } else {
	    @f0 = $mc->get($f0);
	} 
        push @f, \@f0;
    }

    my @res = ();

    my $append = sub {
        my $s = shift;
        if (defined($res[$#res])) {
            if (defined($s)) {
                $res[$#res] .= ' ' . $s;
            }
        } else {
            $res[$#res] = $s;
        }
    };

    my $more = 1;
    for (my $i = 0; $more; $i++) {
        $more = 0;
        $res[@res] = undef;
        for (my $j = 0; $j < +@f; $j++) {
            my $f0 = $f[$j];
            if (+@$f0 > $i) {
                if ( +@$f0 > $i + 1) {
                    $more = 1;
                }
                $append->($f0->[$i]);
            }
        }
    }

    if (defined($fallback)) {
        for (my $i = 0; $i < @res; $i++) {
            unless (defined($res[$i])) {
                $res[$i] = $fallback->($i);
            }
        }
    }

    while (scalar(@res) > 0 && !defined($res[$#res])) {
	pop @res;
    }

    $mc->set($to, @res);
}

sub copy_merge_with_fallback {
    my ($mc, $from, $fallback, $to, $default) = @_;
    my @fallbacks = $mc->get($fallback);
    copy_merge($mc, $from, $to, sub {
        my $i = shift;
        return defined($fallbacks[$i]) ? $fallbacks[$i] : $default;
    });
}

sub cmp_records {
    my ($a, $b) = @_;

    my @diffs = ();
    
    if ($a->leader ne $b->leader) {
	push @diffs, { leader => { a => $a->leader, b => $b->leader } };
    }

    my $afields = {};

    for my $afield  ($a->fields) {
	if (!defined $afields->{$afield->tag}) {
	    $afields->{$afield->tag} = $a->field($afield->tag);
	}
    }
    my $bfields = {};

    for my $bfield  ($b->fields) {
	if (!defined $bfields->{$bfield->tag}) {
	    $bfields->{$bfield->tag} = $b->field($bfield->tag);
	}
    }

    for my $tag (keys(%$afields)) {
	my @af = $afields->{$tag};
	my @bf = $bfields->{$tag};
	delete($afields->{$tag});
	delete($bfields->{$tag});

	my $alen = @af ? scalar(@af) : 0;
	my $blen = @bf ? scalar(@bf) : 0;
	my $max = $alen > $blen ? $alen : $blen;

	for (my $i = 0; $i < $max; $i++) {
	    if ($i >= $alen) {
		push @diffs, { "tag_$tag" => { b => $bf[$i] }};
		next;
	    }
	    if ($i >= $blen) {
		push @diffs, { "tag_$tag" => { a => $af[$i] }};
		next;
	    }
	    push @diffs, cmp_fields($af[$i], $bf[$i]);
	}
    }

    for my $tag (keys(%$bfields)) {
	push @diffs, { "tag_$tag" => { b => $bfields->{$tag} }};
    }

    return @diffs;
}

sub cmp_fields {
    my ($a, $b) = @_;

    my @diffs = ();

    if (!defined $a) {
	push @diffs, { $b->tag => { b -> $b } };
	return @diffs;
    }
    if (!defined $b) {
	push @diffs, { $a->tag => { a => $a } };
	return @diffs;
    }
    
    if ($a->tag ne $b->tag) {
	push @diffs, { 'tag' => { a => $a->tag, b => $b->tag }};
	return @diffs;
    }

    my $aind = defined($a->indicator(1)) ? $a->indicator(1) : '';
    my $bind = defined($b->indicator(1)) ? $b->indicator(1) : '';
    if ($aind ne $bind) {
	push @diffs, { ("tag" . $a->tag . "ind1") => { a => $a->indicator(1), b =>  $b->indicator(1) }};
    }

    $aind = defined($a->indicator(2)) ? $a->indicator(2) : '';
    $bind = defined($b->indicator(2)) ? $b->indicator(2) : '';
    if ($aind ne $bind) {
	push @diffs, { ("tag" . $a->tag . "ind2") => { a => $a->indicator(2), b =>  $b->indicator(2) }};
    }

    if ($a->is_control_field) {
	if ($a->data ne $b->data) {
	    push @diffs, { $a->tag => { a => $a->data, b => $b->data }};
	}
    } else {
	my $asfs = {};
	for my $sf ($a->subfields) {
	    if (!defined $asfs->{$sf->[0]}) {
		$asfs->{$sf->[0]} = [];
	    }
	    push @{$asfs->{$sf->[0]}}, $sf->[1];
	}
	my $bsfs = {};
	for my $sf ($b->subfields) {
	    if (!defined $bsfs->{$sf->[0]}) {
		$bsfs->{$sf->[0]} = [];
	    }
	    push @{$bsfs->{$sf->[0]}}, $sf->[1];
	}
	
	for my $sft (keys %$asfs) {
	    my $as = $asfs->{$sft};
	    my $bs = $bsfs->{$sft};
	    delete($asfs->{$sft});
	    delete($bsfs->{$sft});
	    my $alen = defined $as ? scalar(@$as) : 0;
	    my $blen = defined $bs ? scalar(@$bs) : 0;
	    my $max = $alen > $blen ? $alen : $blen;
	    for (my $i = 0; $i < $max; $i++) {
		if ($i >= $alen) {
		    push @diffs, { ($a->tag . ' ' . $sft) => { b => $bs->[$i] } };
		    next;
		}
		if ($i >= $blen) {
		    push @diffs, { ($a->tag . ' ' . $sft) => { a => $as->[$i] } };
		    next;
		}
		if ($as->[$i] ne $bs->[$i]) {
		    push @diffs, { ($a->tag . ' ' . $sft) => { a => $as->[$i], b => $bs->[$i] } };
		}
	    }
	}
	for my $sft (keys %$bsfs) {
	    push @diffs, { ($a->tag . ' ' . $sft) => { b => $bsfs->{$sft} } }
	}

    }
    return @diffs;
}

1;
