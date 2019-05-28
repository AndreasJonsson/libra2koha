package RecordUtils;

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(copy copy_merge copy_merge_with_fallback);
@EXPORT_OK   = qw();

use Modern::Perl;


sub copy {
    my ($mc, $from, $to) = @_;

    $mc->set($to, $mc->get($from));
}

sub copy_merge {
    my ($mc, $from, $to, $fallback) = @_;

    my @f = ();
    for my $f0 (@$from) {
        my @f0 = $mc->get($f0);
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

1;
