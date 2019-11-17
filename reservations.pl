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
use StatementPreparer;
use TimeUtils;

$YAML::Syck::ImplicitUnicode = 1;

my ($opt, $usage) = describe_options(
    '%c %o <some-arg>',
    [ 'configdir=s',  'config directory' , { required => 1 } ],
    [ 'batch=i', 'batch number', { required => 1 } ],
    [ 'format=s',  'Source format' , { default => 'libra' } ],

           [],
           [ 'verbose|v',  "print extra stuff"            ],
           [ 'help',       "print usage message and exit", { shortcircuit => 1 } ],
         );

print $usage->text if ($opt->help);

my $config;
if ( -f ($opt->configdir . '/config.yaml') ) {
    $config = LoadFile( $opt->configdir . '/config.yaml' );
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

our $dbh = DBI->connect( $config->{'db_dsn'},
                        $config->{'db_user'},
                        $config->{'db_pass'},
                        { RaiseError => 1, AutoCommit => 1 } );
 
init_time_utils(sub { $dbh->quote(shift); });

my $preparer = new StatementPreparer(format => $opt->format, dbh => $dbh);
my $sth = $preparer->prepare('select_reservation_info');

my $ret = $sth->execute();
die "Failed to execute sql query." unless $ret;

my %priorities = ();

print <<EOF;
CREATE TABLE IF NOT EXISTS k_reservations_idmap (
    `original_id` INT NOT NULL,
    `reserve_id` INT NOT NULL,
    `batch` INT NOT NULL,
    PRIMARY KEY (`original_id`,`batch`),
    UNIQUE KEY `reserve_id` (`reserve_id`),
    KEY `k_reservations_idmap_original_id` (`original_id`),
    FOREIGN KEY (`reserve_id`) REFERENCES `reserves`(`reserve_id`) ON DELETE CASCADE ON UPDATE CASCADE
);
EOF


while (my $row = $sth->fetchrow_hashref()) {

    my $pickbranch = $branchcodes->{$row->{'FromIdBranchCode'}};
    next if (!defined $pickbranch || $pickbranch eq '');

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
	if (!defined($row->{IdItem}) || $row->{IdItem} == 0) {
	    $status_str = 'NULL';
	} else {
	    $status_str = "'W'";
	}
    } elsif ($row->{Status} eq 'S') {
	$status_str = "'T'";
    }

    $row->{BarCode} = (split ';', $row->{BarCode})[0] if defined($row->{BarCode});

    my @parts = split ' ', $row->{RegDate};
    if (scalar(@parts) > 1) {
	$row->{RegDate} = $parts[0];
	$row->{RegTime} = $parts[1];
    }

    if (!defined($row->{IdBorrower})) {
	$row->{IdBorrower} = 'NULL';
    }

    if (defined($row->{IdItem})) {
	$row->{original_item_id} = $row->{IdItem};
    } else {
	$row->{original_item_id} = 'NULL';
    }

    my $params = {
	isbn_issn        => $dbh->quote($row->{ISBN_ISSN}),
	titleno          => $dbh->quote($row->{TITLE_NO}),
	borrower_barcode => $dbh->quote($row->{BarCode}),
	item_barcode     => $dbh->quote($row->{ItemBarCode}),
	reservedate      => ds($row->{ResDate}),
	holdingbranch    => $dbh->quote($branchcodes->{$row->{'FromIdBranchCode'}}),
	pickbranch       => $dbh->quote($pickbranch),
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
	IdBorrower       => $row->{IdBorrower},
	original_item_id => $row->{original_item_id},
	original_reservation_id => $row->{IdReservation},
	batch            => $opt->batch
    };

    
    $tt2->process( 'reservations.tt', $params, \*STDOUT, {binmode => ':utf8'}) || die $tt2->error();

}


