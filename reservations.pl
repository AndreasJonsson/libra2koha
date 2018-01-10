#!/usr/bin/perl -w

# reserves
# +------------------+-------------+------+-----+-------------------+-----------------------------+
# | Field            | Type        | Null | Key | Default           | Extra                       |
# +------------------+-------------+------+-----+-------------------+-----------------------------+
# | reserve_id       | int(11)     | NO   | PRI | NULL              | auto_increment              |
# | borrowernumber   | int(11)     | NO   | MUL | 0                 |                             |
# | reservedate      | date        | YES  |     | NULL              |                             |
# | biblionumber     | int(11)     | NO   | MUL | 0                 |                             |
# | branchcode       | varchar(10) | YES  | MUL | NULL              |                             |
# | notificationdate | date        | YES  |     | NULL              |                             |
# | reminderdate     | date        | YES  |     | NULL              |                             |
# | cancellationdate | date        | YES  |     | NULL              |                             |
# | reservenotes     | mediumtext  | YES  |     | NULL              |                             |
# | priority         | smallint(6) | YES  | MUL | NULL              |                             |
# | found            | varchar(1)  | YES  |     | NULL              |                             |
# | timestamp        | timestamp   | NO   |     | CURRENT_TIMESTAMP | on update CURRENT_TIMESTAMP |
# | itemnumber       | int(11)     | YES  | MUL | NULL              |                             |
# | waitingdate      | date        | YES  |     | NULL              |                             |
# | expirationdate   | date        | YES  |     | NULL              |                             |
# | lowestPriority   | tinyint(1)  | NO   |     | NULL              |                             |
# | suspend          | tinyint(1)  | NO   |     | 0                 |                             |
# | suspend_until    | datetime    | YES  |     | NULL              |                             |
# | itemtype         | varchar(10) | YES  | MUL | NULL              |                             |
# +------------------+-------------+------+-----+-------------------+-----------------------------+

# tmp_holdsqueue
# +--------------------+--------------+------+-----+---------+-------+
# | Field              | Type         | Null | Key | Default | Extra |
# +--------------------+--------------+------+-----+---------+-------+
# | biblionumber       | int(11)      | YES  |     | NULL    |       |
# | itemnumber         | int(11)      | YES  |     | NULL    |       |
# | barcode            | varchar(20)  | YES  |     | NULL    |       |
# | surname            | mediumtext   | NO   |     | NULL    |       |
# | firstname          | text         | YES  |     | NULL    |       |
# | phone              | text         | YES  |     | NULL    |       |
# | borrowernumber     | int(11)      | NO   |     | NULL    |       |
# | cardnumber         | varchar(16)  | YES  |     | NULL    |       |
# | reservedate        | date         | YES  |     | NULL    |       |
# | title              | mediumtext   | YES  |     | NULL    |       |
# | itemcallnumber     | varchar(255) | YES  |     | NULL    |       |
# | holdingbranch      | varchar(10)  | YES  |     | NULL    |       |
# | pickbranch         | varchar(10)  | YES  |     | NULL    |       |
# | notes              | text         | YES  |     | NULL    |       |
# | item_level_request | tinyint(4)   | NO   |     | 0       |       |
# +--------------------+--------------+------+-----+---------+-------+

# hold_fill_targets
# +--------------------+-------------+------+-----+---------+-------+
# | Field              | Type        | Null | Key | Default | Extra |
# +--------------------+-------------+------+-----+---------+-------+
# | borrowernumber     | int(11)     | NO   | MUL | NULL    |       |
# | biblionumber       | int(11)     | NO   | MUL | NULL    |       |
# | itemnumber         | int(11)     | NO   | PRI | NULL    |       |
# | source_branchcode  | varchar(10) | YES  | MUL | NULL    |       |
# | item_level_request | tinyint(4)  | NO   |     | 0       |       |
# +--------------------+-------------+------+-----+---------+-------+


# ReservationBranchspec

# IdReservation   int     ^M
# IdBranchCode    varchar 10^M
# IdCat   int     ^M
# IdLoanInfo      int     ^M
# Priority        int     ^M

# Reservationsspec

# IdReservation   int     ^M
# IdCat   int     ^M
# IdBorrower      int     ^M
# GetIdBranchCode varchar 10^M
# FromIdBranchCode        varchar 10^M
# ResDate varchar 8^M
# Age     int     ^M
# Fee     decimal ^M
# Number  int     ^M
# Type    varchar 1^M
# IdItem  int     ^M
# Status  varchar 1^M
# Info    nvarchar        255^M
# StartDate       varchar 8^M
# StopDate        varchar 8^M
# SendDate        varchar 8^M
# SendType        varchar 1^M
# FromWeb int     ^M
# SerialParallelId        int     ^M
# SerialOrder     int     ^M
# ILL     smallint        ^M
# RegDate varchar 8^M
# RegTime varchar 8^M
# RegSign varchar 50^M
# UpdatedDate     varchar 8^M
# UpdatedTime     varchar 8^M
# UpdatedSign     varchar 50^M
# IdIssue int     ^M
# GlobalRes       smallint        ^M
# Printed smallint        ^M

use Modern::Perl;
use YAML::Syck qw( LoadFile );
use Getopt::Long::Descriptive;
use DBI;
use Data::Dumper;
use DateTime::Format::Builder;
use Template;


my ($opt, $usage) = describe_options(
    '%c %o <some-arg>',
    [ 'configdir=s',  'config directory' , { required => 1 } ],

           [],
           [ 'verbose|v',  "print extra stuff"            ],
           [ 'help',       "print usage message and exit", { shortcircuit => 1 } ],
         );

print $usage->text if ($opt->help);

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

my $sth = $dbh->prepare( 'SELECT ISBN_ISSN, TITLE_NO, Reservations.*, BorrowerBarCodes.BarCode as BarCode, ItemBarCodes.BarCode AS ItemBarCode, FirstName, LastName, Title, Author FROM Reservations JOIN BorrowerBarCodes USING (IdBorrower) JOIN Borrowers USING(IdBorrower) JOIN CA_CATALOG ON CA_CATALOG_ID=Reservations.IdCat LEFT OUTER JOIN Items ON (Items.IdItem = Reservations.IdItem) LEFT OUTER JOIN ItemBarCodes ON (ItemBarCodes.IdItem = Items.IdItem) ORDER BY IdCat, RegDate ASC, RegTime ASC' );

my $ret = $sth->execute();
die "Failed to execute sql query." unless $ret;

my %priorities = ();

while (my $row = $sth->fetchrow_hashref()) {

    if (!defined($priorities{$row->{IdCat}})) {
	$priorities{$row->{IdCat}} = 1;
    } else {
	$priorities{$row->{IdCat}}++;
    }

    my $priority = $priorities{$row->{IdCat}};
    
    my $status_str;
    if ($row->{Status} eq 'A') {
	$status_str = "'W'";
    } elsif ($row->{Status} eq 'R') {
	if ($row->{IdItem} == 0) {
	    $status_str = 'NULL';
	} else {
	    $status_str = "'W'";
	}
    } elsif ($row->{Status} eq 'S') {
	next;
    }
    
    my $params = {
	isbn_issn        => $dbh->quote($row->{ISBN_ISSN}),
	titleno          => $dbh->quote($row->{TITLE_NO}),
	borrower_barcode => $dbh->quote($row->{BarCode}),
	item_barcode     => $dbh->quote($row->{ItemBarCode}),
	reservedate      => ds($row->{ResDate}),
	holdingbranch    => $dbh->quote($branchcodes->{$row->{'FromIdBranchCode'}}),
	pickbranch       => $dbh->quote($branchcodes->{$row->{'GetIdBranchCode'}}),
	notificationdate => ds($row->{SendDate}),
	reminderdate     => ds($row->{NotificationDate}),
	cancellationdate => 'NULL',
	reservenotes     => $dbh->quote($row->{Info}),
	priority         => $priority,
	found            => $status_str,
	timestamp        => ts($row->{RegDate}, $row->{RegTime}),
	waitingdate      => ds($row->{SendDate}),
	expirationdate   => ds($row->{StopDate}),
	lowestPriority   => 1,
	suspend          => 0,
	suspend_until    => 'NULL',
	itemtype         => 'NULL',
	surname          => $dbh->quote($row->{LastName}),
	firstname        => $dbh->quote($row->{FirstName}),
	title            => $dbh->quote($row->{Title}),
	author           => $dbh->quote($row->{Author}),
    };

    
    $tt2->process( 'reservations.tt', $params, \*STDOUT, {binmode => ':utf8'}) || die $tt2->error();

}


