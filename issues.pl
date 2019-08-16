#!/usr/bin/perl

# Copyright 2015 Magnus Enger Libriotech

=head1 NAME

issues.pl - Extract information about active issues (loans) and format for import into Koha.

=head1 SYNOPSIS

 perl issues.pl -v --config /home/my/library/

=cut

use DBI;
use Getopt::Long::Descriptive;
use YAML::Syck qw( LoadFile );
use Term::ProgressBar;
use Template;
use DateTime;
use Pod::Usage;
use Modern::Perl;
use Data::Dumper;
use StatementPreparer;
use TimeUtils qw(ds ts init_time_utils);


$YAML::Syck::ImplicitUnicode = 1;

binmode STDOUT, ":utf8";
$|=1; # Flush output


my ($opt, $usage) = describe_options(
    '%c %o <some-arg>',
    [ 'config=s', 'config directory', { required => 1 } ],
    [ 'batch=i', 'batch number', { required => 1 } ],
    [ 'limit=i', 'Limit processing to this number of items.  0 means process all.', { default => 0 } ],
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

=head1 CONFIG FILES

Config files should be kept in one directory and pointed to by the -c or
--config option.

=head2 config.yaml

The main configuration file. Contains things like username and password for
connecting to the database.

See config-sample.yaml for an example.

=cut

my $config;
if ( -f $opt->config . '/config.yaml' ) {
    $config = LoadFile( $opt->config . '/config.yaml' );
}
my $output_file = $config->{'output_marcxml'};

=head2 branchcodes.yaml

Mapping from Branches.IdBRanchCode in Libra to branchcodes in Koha. Have a look
at Branches.txt in the exported data to get an idea of what should go into this
mapping.

=cut

my $branchcodes;
if ( -f $opt->config . '/branchcodes.yaml' ) {
    $branchcodes = LoadFile( $opt->config . '/branchcodes.yaml' );
}

=head2 patroncategories.yaml

Mapping from Borrowers.IdBorrowerCategory in Libra to patron categories in Koha.
Have a look at BorrowerCategories.txt in the exported data to get an idea of
what should go into this mapping.

=cut

my $patroncategories;
if ( -f $opt->config . '/patroncategories.yaml' ) {
    $patroncategories = LoadFile( $opt->config . '/patroncategories.yaml' );
}

# Set up the database connection
my $dbh = DBI->connect( $config->{'db_dsn'}, $config->{'db_user'}, $config->{'db_pass'}, { RaiseError => 1, AutoCommit => 1 } );

my $preparer = new StatementPreparer(format => $opt->format, dbh => $dbh);
init_time_utils(sub { return $dbh->quote(shift); });

my $limit = $opt->limit;
if ($opt->limit == 0) {
    my $sth_ic = $preparer->prepare('select_issue_count');
    $sth_ic->execute() or die "Failed to count issues.";
    $limit = $sth_ic->fetchrow_arrayref()->[0];
}
my $progress = Term::ProgressBar->new( $limit );


# Query for selecting all issues, with relevant data
my $sth = $preparer->prepare('select_issue_info');

=head1 PROCESS ISSUES

Walk through all issues and perform necesarry actions.

=cut

say STDERR "Starting issues iteration" if $opt->verbose;
my $count = 0;

# Configure Template Toolkit
my $ttconfig = {
    INCLUDE_PATH => '',
    ENCODING => 'utf8'  # ensure correct encoding
};
# create Template object
my $tt2 = Template->new( $ttconfig ) || die Template->error(), "\n";

$sth->execute();

print <<EOF;
CREATE TABLE IF NOT EXISTS k_issues_idmap (
    `original_id` INT NOT NULL,
    `issue_id` INT NOT NULL,
    `batch` INT,
    PRIMARY KEY (`original_id`,`batch`),
    UNIQUE KEY `issue_id` (`issue_id`),
    KEY `k_issues_idmap_original_id` (`original_id`),
    FOREIGN KEY (`issue_id`) REFERENCES `issues`(`issue_id`) ON DELETE CASCADE ON UPDATE CASCADE
);
EOF


while ( my $issue = $sth->fetchrow_hashref() ) {

    say STDERR Dumper $issue if $opt->debug;

    # Massage data
    $issue->{'branchcode'} = $branchcodes->{ $issue->{'IdBranchCode'} };
    my $bb = $issue->{'BorrowerIdBranchCode'};
    $issue->{'borrower_branchcode'} = $dbh->quote(defined($bb) ? $branchcodes->{ $bb } : 'NULL');

    $issue->{'issuedate'} = ds( $issue->{'RegDate'} );

    

    $issue->{'date_due'} = ds( $issue->{'EstReturnDate'} );


    
    $issue->{'note'} = $dbh->quote($issue->{'Note'});

    if (!defined($issue->{'NoOfRenewals'})) {
	$issue->{'NoOfRenewals'} = 0;
    }

    if (defined($issue->{'IdItem'})) {
	$issue->{original_item_id} = $issue->{'IdItem'};
    } else {
	$issue->{original_item_id} = 'NULL';
    }
    $issue->{original_issue_id} = $issue->{IdTransaction};
    $issue->{batch} = $opt->batch;


    if ($issue->{'branchcode'} eq '') {
	next;
    } else {
	$tt2->process( 'issues.tt', $issue, \*STDOUT, {binmode => ':utf8'} ) || die $tt2->error();

	$count++;
	if ( $limit && $limit == $count ) {
	    last;
	}
	$progress->update( $count );
    }

} # end foreach record

$progress->update( $limit );

=head1 AUTHOR

Magnus Enger, <magnus [at] libriotech.no>

=head1 LICENSE

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut
