#!/usr/bin/perl -w

use Modern::Perl;
use YAML::Syck qw( LoadFile );
use Getopt::Long::Descriptive;
use DBI;
use Data::Dumper;
use Template;
use utf8;
use StatementPreparer;
use TimeUtils;

sub fix_charcode {
    my $s = shift;
    #utf8::decode($s);
    return $s;
}

my ($opt, $usage) = describe_options(
    '%c %o <some-arg>',
    [ 'configdir=s',  'config directory' , { required => 1 } ],
    [ 'format=s',  'Source format' , { default => 'libra' } ],
    
           [],
           [ 'verbose|v',  "print extra stuff"            ],
           [ 'help',       "print usage message and exit", { shortcircuit => 1 } ],
         );

my $config;
if ( -f ($opt->configdir . '/config.yaml') ) {
    $config = LoadFile( $opt->configdir . '/config.yaml' );
}


our $dbh = DBI->connect( $config->{'db_dsn'},
                        $config->{'db_user'},
                        $config->{'db_pass'},
                        { RaiseError => 1, AutoCommit => 1 } );


my $preparer = new StatementPreparer(format => $opt->format, dbh => $dbh);
init_time_utils(sub { return $dbh->quote(shift); });

my $branchcodes;
if ( -f $opt->configdir . '/branchcodes.yaml' ) {
    $branchcodes = LoadFile( $opt->configdir . '/branchcodes.yaml' );
}

# Configure Template Toolkit
my $ttconfig = {
    INCLUDE_PATH => '', 
    ENCODING => 'utf8'
};
# create Template object
my $tt2 = Template->new( $ttconfig ) || die Template->error(), "\n";


my $sth = $preparer->prepare('select_accountlines');

my $ret = $sth->execute();
die "Failed to execute sql query." unless $ret;

my $current_IdBorrower;
my $current_line;
my $end = 0;

sub next_borrower_row {

    if (!defined($current_line)) {
	$current_line = $sth->fetchrow_hashref();
	$end = !defined($current_line);
    }

    if (!$end && (!defined($current_IdBorrower) || $current_line->{IdBorrower} == $current_IdBorrower) ) {
	my $ret = $current_line;
	undef($current_line);
	$current_IdBorrower = $ret->{IdBorrower};
	return $ret;
    }

    return undef;
}

sub next_borrower {
    undef($current_IdBorrower);
    return !$end;
}

my %borrowers = ();

sub account_idstring {
    my $row = shift;
    my $barcode = shift;

    return '' . (defined($barcode) ? $barcode : '|') .
           '-' . (defined($row->{ItemBarCode}) ? $row->{ItemBarCode}  : '|') . '-' . $row->{has_transaction} . '-' . $row->{Name}
}

sub account_type {
    my $row = shift;
    my $n  = $row->{Name};
    
    if ($n eq 'MSG_FEE') {
	return 'F';
    } elsif ($n eq 'DELAY_FEE_COPY') {
	return 'M';
    } elsif ($n eq 'ILL_BOOKING_FEE') {
	return 'M';
    } elsif ($n eq 'OTHER_FEE') {
	return 'M';
    } elsif ($n eq 'Övertidsavgift') {
	return 'O';
    } elsif ($n eq 'Påminnelseavgift') {
	return 'F';
    } elsif ($n eq 'Reservationsavgift') {
	return 'M';
    } elsif ($n eq 'Räkningsavgift') {
	return 'F';
    } elsif ($n eq 'Förstörda/förkomna') {
	return 'L';
    } elsif ($n eq 'Diverse') {
	return 'M';
    } elsif ($n eq 'Fjärrlån') {
	return 'M';
    } elsif ($n eq 'Fjärrlån kopia') {
	return 'M';
    } elsif ($n eq 'Betalning') {
	return 'Pay';
    } elsif ($n eq 'Return transfer fee') {
	return 'M';
    }  elsif ($n eq 'Låneavgift') {
	return 'M';
    } else {
	die "Unknown fee type: '$n'";
    }
    
}

sub id {
    return @_ if wantarray;
    return $_[0];
}

sub eq0 {
    my ($a, $b) = @_;
    return !defined($a) && !defined($b) || defined($a) && defined($b) && $a eq $b;
}

while (next_borrower()) {

    my %borrower;
    my $accountno = 0;
    my %accounts = ();

    while (my $row = next_borrower_row()) {
	my $barcode;
	if (defined($row->{ItemBarCode})) {
	    $barcode = $row->{ItemBarCode};
	} elsif (defined($row->{ReservationBarCode})) {
	    $barcode = $row->{ReservationBarCode};
	}

	my $accountid = account_idstring($row, $barcode);

	my $account;
	if (defined($row->{BarCode})) {
	    $row->{BarCode} = (split ';', $row->{BarCode})[0];
	}

	my @parts = split ' ', $row->{RegDate};
	if (scalar(@parts) > 1) {
	    $row->{RegDate} = $parts[0];
	    $row->{RegTime} = $parts[1];
	}

	$row->{Amount} = defined($row->{Amount}) ? $row->{Amount} : 0;

	if (!defined($accounts{$accountid})) {
	    $account = {
		original_borrower_id => $row->{IdBorrower},
		original_item_id => $row->{IdItem},
		accounttype => account_type($row),
		amount => $row->{Amount},
		amountoutstanding => $row->{Amount},
		lastincrement => $row->{Amount},
		barcode => $barcode,
		cardnumber => $row->{BarCode},
		surname => $row->{LastName},
		firstname => $row->{FirstName},
		dateenrolled => ds( $row->{DateEnrolled} ),
		issuedate => ds( $row->{TransactionDate} ),
		date => ds( $row->{RegDate} ),
		timestamp => ts( $row->{RegDate}, $row->{RegTime} ),
		description => fix_charcode($row->{Text}),
		note => 'note',
		dispute => 'dispute',
		branchcode => $branchcodes->{ $row->{'IdBranchCode'} },
		DebtName => $row->{Name}
	    };
	    $accounts{$accountid} = $account;
	} else {
	    $account = $accounts{$accountid};
	    $account->{amountoutstanding} += $row->{Amount};
	    $account->{lastincrement} = $row->{Amount};


	    die "accounttype mismatch: '" . $account->{accounttype} . "' ne '" . account_type($row) . "'" unless eq0($account->{accounttype}, account_type($row));
	    die "barcode mismatch: '" . $account->{barcode} . "' ne '" . $barcode . "'" unless eq0($account->{barcode}, $barcode);
	    die "cardnumber mismatch: '" . $account->{cardnumber} . "' ne '" . $row->{BarCode} . "'" unless eq0($account->{cardnumber}, $row->{BarCode});
	    die "surname mismatch: '" . $account->{surname} . "' ne '" . $row->{LastName} . "'"  unless eq0($account->{surname}, $row->{LastName});
	    die "firstname mismatch: '" . $account->{firstname} . "' ne '" . $row->{FirstName} . "'"  unless eq0($account->{firstname}, $row->{FirstName});
	}

	#if (defined($row->{PaymentAmount})) {
	#$account->{amountoutstanding} -= $row->{PaymentAmount};
	#$account->{lastincrement} = -$row->{PaymentAmount};
	#}
    }

    for my $account (values %accounts) {
	_quote(\$account->{accounttype});
	_quote(\$account->{barcode});
	_quote(\$account->{cardnumber});
	_quote(\$account->{surname});
	_quote(\$account->{firstname});
	_quote(\$account->{description});
	_quote(\$account->{note});
	_quote(\$account->{dispute});
	_quote(\$account->{branchcode});

	$account->{accountno} = $accountno;
	$accountno++;
	$tt2->process( 'accountlines.tt', $account, \*STDOUT, {binmode => ':utf8'} ) || die $tt2->error();	
    }
}

sub _quote {
    my $s = shift;

    if (defined($$s)) {
	$$s = $dbh->quote($$s);
    } else {
	$$s = 'NULL';
    }
}

sub _quoten {
    my $s = shift;

    if (defined($$s)) {
	$$s = $dbh->quote($$s);
    } else {
	$$s = "''";
    }
}
