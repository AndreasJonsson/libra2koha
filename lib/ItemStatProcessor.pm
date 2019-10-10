package ItemStatProcessor;

sub new {
    my ($class, $opt) = @_;
    return bless {

    };

}

sub process {
    my ($self, $mmc, $item) = @_;

    if (defined $item->{LoanCount}) {
	$mmc->set('items.issues', $item->{LoanCount});
    }

    if (defined $item->{RenewalCount}) {
	$mmc->set('items.renewals', $item->{RenewalCount});
    }
}

1;
