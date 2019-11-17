package MusicPublishNoItemProcessor;

sub new {
    my ($class, $opt) = @_;
    return bless {
    };
}

sub is_pn {
    my $_ = shift;

    return defined $_ && /^((CD)|(LP)|(DVD))$/;
}

sub process {
    my ($self, $mmc, $item) = @_;

    my $pn = $mmc->get('publish_no');

    $pn = $item->{PublishNo} if !is_pn($pn);
    $pn = $item->{NoteExt} if !is_pn($pn);

    my $noteext = $item->{NoteExt};
    
    if (is_pn($pn) && !substr($noteext, $pn)) {
	if (defined $noteext && $noteext ne '') {
	    $noteext .= "\n" . $pn;
	} else {
	    $noteext = $pn;
	}
    }

    $mmc->set('items.itemnotes', $noteext);
}


1;

