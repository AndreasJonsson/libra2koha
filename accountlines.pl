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
use RecordUtils;

$YAML::Syck::ImplicitUnicode = 1;

binmode STDOUT, ":utf8";
$|=1; # Flush output

sub fix_charcode {
    my $s = shift;
    #utf8::decode($s);
    return $s;
}

my ($opt, $usage) = describe_options(
    '%c %o <some-arg>',
    [ 'configdir=s',  'config directory' , { required => 1 } ],
    [ 'format=s',  'Source format' , { default => 'libra' } ],
    [ 'string-original-id', 'If datatype of original id is string.  Default is integer.' ],
    
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


my $preparer = new StatementPreparer(format => $opt->format, dbh => $dbh, dir => [$opt->configdir]);
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

    my $same_borrower = !defined($current_IdBorrower) || ($opt->string_original_id ?
	$current_line->{IdBorrower} eq $current_IdBorrower :
	$current_line->{IdBorrower} == $current_IdBorrower);

    if (!$end && ($same_borrower) ) {
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

sub set_type {
    my $row = shift;
    my $account = shift;
    my $n  = $row->{Name};

    my ($d, $c);
    if (defined $n) {
	if ($n eq 'MSG_FEE') {
	    $d = 'OVERDUE';
	} elsif ($n eq 'DELAY_FEE_COPY') {
	    $d = 'OVERDUE';
	} elsif ($n eq 'ILL_BOOKING_FEE') {
	    $d = 'RESERVE';
	} elsif ($n eq 'OTHER_FEE') {
	    $d = 'MANUAL';
	} elsif ($n eq 'BOOKING_FEE_NO_PICKUP') {
	    $d = 'MANUAL';
	} elsif ($n eq 'Övertidsavgift') {
	    $d = 'OVERDUE';
	} elsif ($n eq 'Påminnelseavgift') {
	    $d = 'OVERDUE';
	} elsif ($n eq 'Reservationsavgift') {
	    $d = 'RESERVE';
	} elsif ($n eq 'Räkningsavgift') {
	    $d = 'MANUAL';
	} elsif ($n eq 'Förstörda/förkomna') {
	    $d = 'LOST';
	} elsif ($n eq 'Diverse') {
	    $d = 'MANUAL';
	} elsif ($n eq 'Fjärrlån') {
	    $d = 'RESERVE';
	} elsif ($n eq 'Fjärrlån kopia') {
	    $d = 'RESERVE';
	} elsif ($n eq 'Betalning') {
	    $c = 'PAYMENT';
	} elsif ($n eq 'Return transfer fee') {
	    $d = 'MANUAL';
	}  elsif ($n eq 'Låneavgift') {
	    $d = 'MANUAL';
	}  elsif ($n eq 'BILL_FEE') {
	    $d = 'MANUAL';
	}  elsif ($n eq 'ILL_LOAN_FEE') {
	    $d = 'MANUAL';
	} else {
	    die "Unknown fee type: '$n'";
	}
    }
    
    if (defined $row->{credit_type}) {
	$account->{credit_type} = uc($row->{credit_type});
    } else {
	$account->{credit_type} = $c;
    }
    _quote(\$account->{credit_type});

    if (defined $row->{debit_type}) {
	$account->{debit_type} = uc($row->{debit_type});
    } else {
	$account->{debit_type} = $d;
    }
    _quote(\$account->{debit_type});
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

	if ($opt->string_original_id) {
	    $row->{IdBorrower} = $dbh->quote($row->{IdBorrower});
	}
	my $branchcode = defined($row->{'IdBranchCode'}) && exists($branchcodes->{ trim($row->{'IdBranchCode'}) })
	    ? $branchcodes->{ trim($row->{'IdBranchCode'}) }
            : $branchcodes->{ '_default' };
	if (!defined($accounts{$accountid})) {
	    $account = {
		original_borrower_id => $row->{IdBorrower},
		original_item_id => $row->{IdItem},
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
		branchcode => $branchcode,
		DebtName => $row->{Name}
	    };
	    set_type($row, $account);
	    $accounts{$accountid} = $account;
	} else {
	    $account = $accounts{$accountid};
	    $account->{amountoutstanding} += $row->{Amount};
	    $account->{lastincrement} = $row->{Amount};


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
