#!/usr/bin/env perl

use Modern::Perl;
use YAML::Syck qw( LoadFile );
use Pod::Usage;
use DBI;
use Getopt::Long::Descriptive;
use Data::Dumper;
use Template;
use StatementPreparer;
use TimeUtils;

$YAML::Syck::ImplicitUnicode = 1;

my ($opt, $usage) = describe_options(
    '%c %o <some-arg>',
    [ 'config=s', 'config directory', { required => 1 } ],
    [ 'outputdir=s', 'output directory', { required => 1 } ],
    [ 'branchcode=s', 'branchcode', { required => 1 } ],
    [ 'batch=i', 'batch number', { required => 1 } ],
    [ 'format=s', 'Input database format', { required => 1 }],
    [],
    [ 'verbose|v',  "print extra stuff"            ],
    [ 'debug',      "Enable debug output" ],
    [ 'help',       "print usage message and exit", { shortcircuit => 1 } ],
);

if ($opt->help) {
    print $usage->text;
    exit 0;
}

my $config;
if ( -f ($opt->config . '/config.yaml') ) {
    $config = LoadFile( $opt->config . '/config.yaml' );
}

our $dbh = DBI->connect( $config->{'db_dsn'},
                        $config->{'db_user'},
                        $config->{'db_pass'},
                        { RaiseError => 1, AutoCommit => 1 } );

init_time_utils(sub { $dbh->quote(shift); });
# Configure Template Toolkit
my $ttconfig = {
    INCLUDE_PATH => '', 
    ENCODING => 'utf8'
};
# create Template object
my $tt2 = Template->new( $ttconfig ) || die Template->error(), "\n";

my $preparer = new StatementPreparer(format => $opt->format, dbh => $dbh);

my $sth = $preparer->prepare( 'select_serials' );
my $serialitems_sth = $preparer->prepare( 'select_serialitems' );

my $ret = $sth->execute();
die "Failed to query serials!" unless (defined($ret));

open SERIALS, ">:encoding(UTF-8)", ($opt->outputdir . "/serials.sql") or die "Failed to open serials.sql for writing: $!";

print SERIALS <<EOF;
CREATE TABLE IF NOT EXISTS `k_serial_idmap` (
    `original_id` INT NOT NULL,
    `serialid` INT NOT NULL,
    `batch` INT,
    PRIMARY KEY (`original_id`,`batch`),
    UNIQUE KEY `serialid` (`serialid`),
    KEY `k_serial_idmap_original_id` (`original_id`),
    FOREIGN KEY (`serialid`) REFERENCES `serial`(`serialid`) ON DELETE CASCADE ON UPDATE CASCADE
);
EOF

while (my $row = $sth->fetchrow_hashref()) {
    #say Dumper($row);
    next unless defined($row->{Name});
    my $serialseq = $dbh->quote($row->{Name});
    my $serialseq_x = $dbh->quote($row->{IssueYear});
    my $serialseq_y = 0;
    if ($serialseq =~ m/ N[ro]\.? *(\d+)$/) {
        $serialseq_y = $1;
    }

    my $planneddate = dp($row->{DateArrival});
    my $publisheddate = dp($row->{ExpectedDateArrival});
    my $status = 0;
    my $biblionumber = $row->{biblioitem};
    my $biblionumber_str = $dbh->quote($biblionumber);

    if (!defined($planneddate)) {
        $status = 1; # expected
    } elsif (defined($publisheddate) && $publisheddate < $planneddate) {
        $status = 3; # late
    } else {
        $status = 2; # arrived
    }

    my $planneddate_str = ds($planneddate);
    my $publisheddate_str = ds($publisheddate);

    my $tt = {
	serialseq    => $serialseq,
	serialseq_x  => $serialseq_x,
	serialseq_y  => $serialseq_y,
	status       => $status,
	planneddate_str => $planneddate_str,
	publisheddate_str => $publisheddate_str,
        issn         => $dbh->quote($row->{ISBN_ISSN}),
	titleno      => $dbh->quote(uc($row->{TITLE_NO})),
	branchcode_str => $dbh->quote($opt->branchcode),
	original_serial_id => $row->{IdIssue},
	batch        => $opt->batch,
	original_ids => []
    };

    $ret = $serialitems_sth->execute( $row->{IdIssue} );
    die "Failed to query serialitems" unless defined($ret);

    while (my $item_row = $serialitems_sth->fetchrow_hashref()) {
	push @{$tt->{original_ids}}, $item_row->{IdItem};
    }

    $tt2->process( 'serials.tt', $tt, \*SERIALS,  {binmode => ':utf8' } ) || die $tt2->error();
}

