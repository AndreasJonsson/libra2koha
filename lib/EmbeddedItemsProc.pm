package EmbeddedItemsProc;

import RecordUtils;
import TimeUtils;
use DateTime;
use DateTime::Format::Builder;

sub new {
    my ($class, $opt, $config_tables) = @_;

    my $date_parser = DateTime::Format::Builder->new()->parser( regex => qr/^(\d{2})-(\d\d)-(\d\d)/,
								params => [qw(year month day)] );
    return bless {
	opt => $opt,
	config_tables => $config_tables,
	dp => $date_parser
    };
}

sub process {
    my ($self, $mmc, $record) = @_;

    if ($self->{opt}->items_format eq 'sierra') {
	$self->do_sierra_items($mmc, {}, {});
    }

    return $record;
}

sub do_sierra_items {
    my $self = shift;
    my $mmc = shift;
    my $bibextra = shift;
    my $loc = shift;

    my $opt = $self->{opt};
    my $branchcodes = $self->{config_tables}->{branchcodes};

    my @sysnumbers = $mmc->get('sierra_sysnumber');
    if ($opt->separate_items) {
	map { $mmc->new_item($_) } @sysnumbers;
    }
    my @branches = map { $opt->default_branchcode } @sysnumbers;

    $mmc->set('items.homebranch', @branches);
    $mmc->set('items.holdingbranch', @branches);
    
    copy($mmc, 'sierra_barcode', 'items.barcode');
    copy($mmc, { m => 'sierra_created', f => sub {
	if (!defined($_[0])) {
	    return;
	}
	my $d = $self->{dp}->parse_datetime($_[0]);
	if ($d->year < 100) {
	    $d = $d->add(years => 2000);
	}
	if (!defined $d) {
	    return;
	}
	return $d->strftime('%F');
		 } }, 'items.dateaccessioned');
    copy($mmc, 'sierra_total_checkouts', 'items.issues');
    copy($mmc, 'sierra_total_renewals', 'items.renewals');
    copy($mmc, { m => 'sierra_price', f => sub {
	if (!defined($_[0])) {
	    return;
	}
	$_[0] =~ /([\d.]+)/; return $1; } }, 'items.price');
    copy($mmc, 'sierra_note', 'items.itemnotes_nonpublic');
    copy($mmc, 'sierra_message', 'items.itemnotes');
    copy_merge($mmc, ['sierra_call_number', 'sierra_call_number_loc'], 'items.itemcallnumber');
    copy($mmc, 'sierra_volume', 'items.enumchron');
    copy($mmc, 'sierra_copy_number', 'items.copynumber');

    #copy($mmc, { m => 'sierra_restricted', f => sub {
    #	if (!defined($_[0])) {
    #	    return
    #	}
    #	my %map = (
    #	    'e' => 1,
    #    'l' => 2,
    #	    'o' => 3
    #	    );
    #	return $map{$_[0]};
    #	
    #}
    # }, 'items.restricted');

    copy($mmc, { m => 'sierra_status', f => sub {
	if (!defined($_[0])) {
	    return
	}
	my %map = $self->{config_tables}->{damaged};
	my $v = $map->{trim($_[0])};
	return defined $v ? $v : $map->{'_default'};
		 }
	 }, 'items.damaged');

    copy($mmc, { m => 'sierra_status', f => sub {
	if (!defined($_[0])) {
	    return
	}
	my $map = $self->{config_tables}->{lost};
	my $v = $map->{trim($_[0])};
	return defined $v ? $v : $map->{'_default'};
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
	my $map = $self->{config_tables}->{itemtypes};
	my $v = $map->{trim($_[0])};
	return defined $v ? $v : $map->{'_default'};
    } }, 'items.itype');

    copy($mmc, { m =>'sierra_location', f => sub {
	if (!defined($_[0])) {
	    return
	}
	my $map = $self->{config_tables}->{loc};
	my $v = $map->{trim($_[0])};
	return defined $v ? $v : $map->{'_default'};
    } }, 'items.location');

    if (defined $bibextra->{'collection_code'}) {
	$mmc->set('items.ccode', $bibextra->{'collection_code'});
    }

    if (defined $bibextra->{'itype'}) {
	$mmc->set('items.itype', $bibextra->{'itype'});
    }

}

1;

