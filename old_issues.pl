#!/usr/bin/perl -w

use Modern::Perl;
use YAML::Syck qw( LoadFile );
use Getopt::Long::Descriptive;
use DBI;
use Data::Dumper;
use DateTime::Format::Builder;
use Template;
use StatementPreparer;
use TimeUtils;

# +------------------+-------------+------+-----+-------------------+-----------------------------+
# | Field            | Type        | Null | Key | Default           | Extra                       |
# +------------------+-------------+------+-----+-------------------+-----------------------------+
# | issue_id         | int(11)     | NO   | PRI | NULL              |                             |
# | borrowernumber   | int(11)     | YES  | MUL | NULL              |                             |
# | itemnumber       | int(11)     | YES  | MUL | NULL              |                             |
# | date_due         | datetime    | YES  |     | NULL              |                             |
# | branchcode       | varchar(10) | YES  | MUL | NULL              |                             |
# | returndate       | datetime    | YES  |     | NULL              |                             |
# | lastreneweddate  | datetime    | YES  |     | NULL              |                             |
# | renewals         | tinyint(4)  | YES  |     | NULL              |                             |
# | auto_renew       | tinyint(1)  | YES  |     | 0                 |                             |
# | auto_renew_error | varchar(32) | YES  |     | NULL              |                             |
# | timestamp        | timestamp   | NO   |     | CURRENT_TIMESTAMP | on update CURRENT_TIMESTAMP |
# | issuedate        | datetime    | YES  |     | NULL              |                             |
# | onsite_checkout  | int(1)      | NO   |     | 0                 |                             |
# | note             | mediumtext  | YES  |     | NULL              |                             |
# | notedate         | datetime    | YES  |     | NULL              |                             |
# +------------------+-------------+------+-----+-------------------+-----------------------------+


my ($opt, $usage) = describe_options(
    '%c %o <some-arg>',
    [ 'configdir=s',  'config directory' , { required => 1 } ],
    [ 'batch=i', 'batch number', { required => 1 } ],
    [ 'format=s',  'Source format' , { default => 'libra' } ],
           [],
    [ 'verbose|v',  "print extra stuff"            ],
    [ 'branchcode|b=s',  "Default branchcode", { required => 1} ],
           [ 'help',       "print usage message and exit", { shortcircuit => 1 } ],
         );

print $usage->text if ($opt->help);

my $config;
if ( -f ($opt->configdir . '/config.yaml') ) {
    $config = LoadFile( $opt->configdir . '/config.yaml' );
}

our $dbh = DBI->connect( $config->{'db_dsn'},
                        $config->{'db_user'},
                        $config->{'db_pass'},
                        { RaiseError => 1, AutoCommit => 1 } );

init_time_utils(sub { $dbh->quote(shift); });
my $preparer = new StatementPreparer(format => $opt->format, dbh => $dbh);

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

my $sth = $preparer->prepare('select_old_issues_info');

my $ret = $sth->execute();
die "Failed to execute sql query." unless $ret;

print <<EOF;
CREATE TABLE IF NOT EXISTS k_old_issues_idmap (
    `original_id` INT NOT NULL,
    `issue_id` INT NOT NULL,
    `batch` INT,
    PRIMARY KEY (`original_id`,`batch`),
    UNIQUE KEY `issue_id` (`issue_id`),
    KEY `k_issues_idmap_original_id` (`original_id`),
    FOREIGN KEY (`issue_id`) REFERENCES `old_issues`(`issue_id`) ON DELETE CASCADE ON UPDATE CASCADE
);
EOF


while (my $row = $sth->fetchrow_hashref()) {

    my $branchcode = defined($row->{IdBranchCode}) && defined($branchcodes->{$row->{IdBranchCode}}) ? $branchcodes->{$row->{IdBranchCode}} : $opt->branchcode;

    my @barcodes = defined($row->{BarCode}) ? split ';', $row->{BarCode} : ();
    my $barcode;
    if (scalar(@barcodes) > 0)  {
	$barcode = $dbh->quote(shift @barcodes);
    } else {
	$barcode = 'NULL';
    }

    if (!defined($row->{IdBorrower})) {
	$row->{IdBorrower} = 'NULL';
    }

    my @parts = split ' ', $row->{RegDate};
    if (scalar(@parts) > 1) {
	$row->{RegDate} = $parts[0];
	$row->{RegTime} = $parts[1];
    }
    
    my $params = {
	titleno => $dbh->quote($row->{TITLE_NO}),
	cardnumber => $barcode,
	callnumber => $dbh->quote($row->{Location_Marc}),
	returndate => ds($row->{RegDate}),
	timestamp  => ts($row->{RegDate}, $row->{RegTime}),
	branchcode => $dbh->quote($branchcode),
	surname =>    $dbh->quote($row->{LastName}),
	firstname =>  $dbh->quote($row->{FirstName}),
	dateenrolled => ds( $row->{DateEnrolled} ),
	item_barcode     => $dbh->quote($row->{ItemBarCode}),
	IdBorrower => $row->{IdBorrower},
	original_issue_id => $row->{IdTransactionsSaved},
	batch => $opt->batch
    };

    $tt2->process( 'old_issues.tt', $params, \*STDOUT, {binmode => ':utf8'}) || die $tt2->error();
}

