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

# Define statuses
use constant {
    EXPECTED               => 1,
    ARRIVED                => 2,
    LATE                   => 3,
    MISSING                => 4,
    MISSING_NEVER_RECIEVED => 41,
    MISSING_SOLD_OUT       => 42,
    MISSING_DAMAGED        => 43,
    MISSING_LOST           => 44,
    NOT_ISSUED             => 5,
    DELETED                => 6,
    CLAIMED                => 7,
    STOPPED                => 8,
};

use constant MISSING_STATUSES => (
    MISSING,          MISSING_NEVER_RECIEVED,
    MISSING_SOLD_OUT, MISSING_DAMAGED,
    MISSING_LOST
);

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

my $branchcodes;
if ( -f $opt->config . '/branchcodes.yaml' ) {
    print STDERR "Loading branchcodes.yaml\n" if $opt->verbose;
    $branchcodes = LoadFile( $opt->config . '/branchcodes.yaml' );
}

my $loc;
if ( -f $opt->config . '/loc.yaml' ) {
    print STDERR "Loading loc.yaml\n" if $opt->verbose;
    $loc = LoadFile( $opt->config . '/loc.yaml' );
}

init_time_utils(sub { $dbh->quote(shift); });
# Configure Template Toolkit
my $ttconfig = {
    INCLUDE_PATH => '', 
    ENCODING => 'utf8'
};
# create Template object
my $tt2 = Template->new( $ttconfig ) || die Template->error(), "\n";

my $preparer = new StatementPreparer(format => $opt->format, dbh => $dbh, dir => [$opt->config]);

my $subscription_sth = $preparer->prepare( 'select_subscriptions' );
my $serials_sth = $preparer->prepare( 'select_serials' );
my $serialseq_sth = $preparer->prepare( 'select_serialseq' );
my $serialitems_sth = $preparer->prepare( 'select_serialitems' );

my $ret = $subscription_sth->execute();
die "Failed to query subscriptions!" unless (defined($ret));

open SERIALS, ">:encoding(UTF-8)", ($opt->outputdir . "/serials.sql") or die "Failed to open serials.sql for writing: $!";

print SERIALS <<EOF;
CREATE TABLE IF NOT EXISTS `k_serial_idmap` (
    `original_id` INT NOT NULL,
    `serialid` INT NOT NULL,
    `batch` INT,
    KEY (`original_id`,`batch`),
    UNIQUE KEY `serialid` (`serialid`),
    KEY `k_serial_idmap_original_id` (`original_id`),
    FOREIGN KEY (`serialid`) REFERENCES `serial`(`serialid`) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE TABLE IF NOT EXISTS `k_subscription_idmap` (
    `original_id` INT NOT NULL,
    `subscriptionid` INT NOT NULL,
    `batch` INT,
    PRIMARY KEY (`original_id`,`batch`),
    UNIQUE KEY `subscriptionid` (`subscriptionid`),
    KEY `k_serial_idmap_original_id` (`original_id`),
    FOREIGN KEY (`subscriptionid`) REFERENCES `subscription`(`subscriptionid`) ON DELETE CASCADE ON UPDATE CASCADE
);
EOF

while (my $subscr = $subscription_sth->fetchrow_hashref()) {

    if (defined ($subscr->{IdBranchCode})) {
	$subscr->{branchcode} = $branchcodes->{$subscr->{IdBranchCode}};
    }

    if (defined $subscr->{IdLocalShelf}) {
	$subscr->{location} = $loc->{$subscr->{IdLocalShelf}};
    }


    for my $field (qw(titleno librarian startdate enddate firstacquidate  reneweddate  notes  internalnotes  location  branchcode)) {
	_quote(\$subscr->{$field});
    }
    for my $field (qw(cost status closed)) {
	_def(\$subscr->{$field});
    }

    $serials_sth->execute($subscr->{original_id});

    $subscr->{serials} = [];

    while (my $serial = $serials_sth->fetchrow_hashref()) {
	if (defined $serial->{serialseq_id}) {
	    $serialseq_sth->execute($serial->{serialseq_id});
		
	    while (my $serialseq = $serialseq_sth->fetchrow_hashref()) {
		$serial->{serialseq_x} = $serialseq->{serialseq_x} if defined $serialseq->{serialseq_x};
		$serial->{serialseq_y} = $serialseq->{serialseq_y} if defined $serialseq->{serialseq_y};
		$serial->{serialseq_z} = $serialseq->{serialseq_z} if defined $serialseq->{serialseq_z};
	    }
	}
	for my $field (qw(titleno serialseq serialseq_x serialseq_y serialseq_z planneddate notes publisheddate publisheddatetext claimdate claims_count routingnotes)) {
	    _quote(\$serial->{$field});
	}
	for my $field (qw(status claims_count)) {
	    _def(\$serial->{$field});
	}
	$serial->{serialitems} = [];
	$ret = $serialitems_sth->execute( $subscr->{original_id}, $serial->{original_id} );
	die "Failed to query serialitems" unless defined($ret);

	while (my $serialitem = $serialitems_sth->fetchrow_hashref()) {
	    push @{$serial->{serialitems}}, $serialitem;
	}
	push @{$subscr->{serials}}, $serial;
    }


    $subscr->{batch} = $opt->batch;


    $tt2->process( 'serials.tt', $subscr, \*SERIALS,  {binmode => ':utf8' } ) || die $tt2->error();
}


sub _quote {
    my $s = shift;

    if (defined($$s)) {
	$$s = $dbh->quote($$s);
    } else {
	$$s = 'DEFAULT';
    }
}

sub _def {
    my $s = shift;

    if (!defined($$s)) {
	$$s = 'DEFAULT';
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


# subscription fields
#    weeklength,
#    monthlength,
#    numberlength,
#    periodicity,
#    countissuesperunit,
#    lastvalue1,
#    innerloop1,
#    lastvalue2,
#    innerloop2,
#    lastvalue3,
#    innerloop3,
#    manualhistory,
#    irregularity,
#    skip_serialseq,
#    letter,
#    numberpattern,
#    locale,
#    distributedto,
#    callnumber,
#    lastbranch,
#    serialsadditems,
#    staffdisplaycount,
#    opacdisplaycount,
#    graceperiod,
#    itemtype,
#    previousitemtype,
#    mana_id


=text
serial fields

    serialid,
    biblionumber,
    subscriptionid,
    serialseq,
    serialseq_x,
    serialseq_y,
    serialseq_z,
    status,
    planneddate,
    notes,
    publisheddate,
    publisheddatetext,
    claimdate,
    claims_count,
    routingnotes,



JOIN PE_FREQ_RULE USING(PE_TITLE_ID)
JOIN PE_FREQ_VALUE ON(PE_FREQ_RULE.PE_FREQ_TYPE_ID=PE_FREQ_VALUE.PE_FREQ_TYPE_ID AND PE_FREQ_RULE.FREQ_RULE=PE_FREQ_VALUE.PE_FREQ_VALUE_ID)
JOIN PE_FREQ_TYPE USING(PE_FREQ_TYPE_ID)



select count(*) 
FROM PE_SUBSCR_ARR
JOIN PE_RELEASE USING(PE_RELEASE_ID)
JOIN PE_PERIOD USING(PE_PERIOD_ID)
JOIN PE_FREQ_RULE USING(PE_TITLE_ID)
=cut
