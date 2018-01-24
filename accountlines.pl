#!/usr/bin/perl -w

use Modern::Perl;
use YAML::Syck qw( LoadFile );
use Getopt::Long::Descriptive;
use DBI;
use Data::Dumper;
use DateTime::Format::Builder;
use Template;
use utf8;

my ($opt, $usage) = describe_options(
    '%c %o <some-arg>',
    [ 'configdir=s',  'config directory' , { required => 1 } ],

           [],
           [ 'verbose|v',  "print extra stuff"            ],
           [ 'help',       "print usage message and exit", { shortcircuit => 1 } ],
         );

my $config;
if ( -f ($opt->configdir . '/config.yaml') ) {
    $config = LoadFile( $opt->configdir . '/config.yaml' );
}

our $date_parser = DateTime::Format::Builder->new()->parser( regex => qr/^(\d{4})(\d\d)(\d\d)$/,
                                                            params => [qw(year month day)] );
our $dbh = DBI->connect( $config->{'db_dsn'},
                        $config->{'db_user'},
                        $config->{'db_pass'},
                        { RaiseError => 1, AutoCommit => 1 } );


our $time_parser = DateTime::Format::Builder->new()->parser( regex => qr/^(\d{4})(\d\d)(\d\d) (\d+):(\d+):(\d+)$/,
							     params => [qw(year month day hour minute second)] );
sub dp {
    my $ds = shift;
    if (!defined($ds) || $ds =~ /^ *$/) {
        return undef;
    }
    return $date_parser->parse_datetime($ds);
}

sub ds {
    my $d = shift;
    $d = dp($d);
    if (defined($d)) {
       return $dbh->quote($d->strftime( '%F' ));
    } else {
       return "NULL";
    }
}

sub tp {
    my $ds = shift;
    my $ts = shift;
    if (!defined($ds) || $ds =~ /^ *$/) {
        return undef;
    }
    if (defined($ts) && !$ds =~ /^ *$/) {
	$ds .= " $ts";
    }
    return $time_parser->parse_datetime($ds);
}

sub ts {
    my $d = shift;
    my $t = shift;
    $d = tp($d, $t);
    if (defined($d)) {
       return $dbh->quote($d->strftime( '%F %T' ));
    } else {
       return "NULL";
    }
}
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


my $sth = $dbh->prepare( <<'EOF' );
SELECT
  b.IdBorrower,
  b.IdBranchCode,
  BorrowerBarCodes.BarCode,
  Transactions.IdItem IS NOT NULL AS has_transaction,
  Transactions.RegDate AS TransactionDate,
  rbc.BarCode AS ReservationBarCode,
  IFNULL(ibc.BarCode, ItemBarCodes.BarCode) as ItemBarCode,
  bdr.Amount,
  FeeTypes.Name,
  bd.Text AS Text,
  bd.RegDate AS RegDate,
  bd.RegTime AS RegTime,
  b.FirstName,
  b.LastName,
  b.RegDate AS DateEnrolled
FROM
  BorrowerDebts AS bd
  JOIN Borrowers AS b USING (IdBorrower)
  LEFT OUTER JOIN BorrowerBarCodes USING(IdBorrower)
  LEFT OUTER JOIN BorrowerDebtsRows AS bdr USING(IdDebt)
  LEFT OUTER JOIN FeeTypes USING (IdFeeType)
  LEFT OUTER JOIN ItemBarCodes USING (IdItem)
  LEFT OUTER JOIN Transactions USING (IdTransaction)
  LEFT OUTER JOIN Reservations USING (IdReservation)
  LEFT OUTER JOIN ItemBarCodes AS rbc ON Reservations.IdItem = rbc.IdItem
  LEFT OUTER JOIN ItemBarCodes AS ibc ON Transactions.IdItem = ibc.IdItem
WHERE
  b.IdBorrower IS NOT NULL
ORDER BY b.IdBorrower, bdr.RegDate ASC, bdr.RegTime ASC
EOF

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

    if ($n eq 'Övertidsavgift') {
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

	if (!defined($accounts{$accountid})) {
	    $account = {
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
		description => $row->{Text},
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
	$account->{DebtName};

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
