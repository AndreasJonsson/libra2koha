#!/usr/bin/perl 
 
# Copyright 2015 Magnus Enger Libriotech
 
=head1 NAME

issues.pl - Extract information about active issues (loans) and format for import into Koha.

=head1 SYNOPSIS

 perl issues.pl -v --config /home/my/library/

=cut

use DBI;
use Getopt::Long;
use YAML::Syck qw( LoadFile );
use Term::ProgressBar;
use Template;
use DateTime;
use Pod::Usage;
use Modern::Perl;
use Data::Dumper;

binmode STDOUT, ":utf8";
$|=1; # Flush output

# Get options
my ( $config_dir, $limit, $every, $verbose, $debug ) = get_options();

$limit = 130889 if $limit == 0; # FIXME Get this from the database
my $progress = Term::ProgressBar->new( $limit );

=head1 CONFIG FILES

Config files should be kept in one directory and pointed to by the -c or
--config option.

=head2 config.yaml

The main configuration file. Contains things like username and password for
connecting to the database.

See config-sample.yaml for an example.

=cut

my $config;
if ( -f $config_dir . '/config.yaml' ) {
    $config = LoadFile( $config_dir . '/config.yaml' );
}
my $output_file = $config->{'output_marcxml'};

=head2 branchcodes.yaml

Mapping from Branches.IdBRanchCode in Libra to branchcodes in Koha. Have a look
at Branches.txt in the exported data to get an idea of what should go into this
mapping.

=cut

my $branchcodes;
if ( -f $config_dir . '/branchcodes.yaml' ) {
    $branchcodes = LoadFile( $config_dir . '/branchcodes.yaml' );
}

=head2 patroncategories.yaml

Mapping from Borrowers.IdBorrowerCategory in Libra to patron categories in Koha.
Have a look at BorrowerCategories.txt in the exported data to get an idea of
what should go into this mapping.

=cut

my $patroncategories;
if ( -f $config_dir . '/patroncategories.yaml' ) {
    $patroncategories = LoadFile( $config_dir . '/patroncategories.yaml' );
}

# Set up the database connection
my $dbh = DBI->connect( $config->{'db_dsn'}, $config->{'db_user'}, $config->{'db_pass'}, { RaiseError => 1, AutoCommit => 1 } );

# Query for selecting all issues, with relevant data
my $sth = $dbh->prepare("
    SELECT t.*, bbc.BarCode AS BorrowerBarcode, ibc.BarCode as ItemBarcode 
    FROM Transactions as t, BorrowerBarCodes as bbc, ItemBarCodes as ibc 
    WHERE t.IdItem = ibc.IdItem
      AND t.IdBorrower = bbc.IdBorrower;
");

=head1 PROCESS ISSUES

Walk through all issues and perform necesarry actions.

=cut

say "Starting issues iteration" if $verbose;
my $count = 0;

# Configure Template Toolkit
my $ttconfig = {
    INCLUDE_PATH => '', 
    ENCODING => 'utf8'  # ensure correct encoding
};
# create Template object
my $tt2 = Template->new( $ttconfig ) || die Template->error(), "\n";

$sth->execute();

while ( my $issue = $sth->fetchrow_hashref() ) {

    say Dumper $issue if $debug;

    # Only do every x record
    if ( $every && ( $count % $every != 0 ) ) {
        $count++;
        next;
    }

    # Massage data
    $issue->{'branchcode'} = $branchcodes->{ $issue->{'IdBranchCode'} };
    $issue->{'issuedate'} = _fix_date( $issue->{'RegDate'} );
    $issue->{'date_due'} = _fix_date( $issue->{'EstReturnDate'} );

    $tt2->process( 'issues.tt', $issue ) || die $tt2->error();

    $count++;
    if ( $limit && $limit == $count ) {
        last;
    }
    $progress->update( $count );

} # end foreach record

$progress->update( $limit );

=head1 OPTIONS

=over 4

=item B<-c, --config>

Path to directory that contains config files. See the section on
L</"CONFIG FILES"> above for more details.

=item B<-l, --limit>

Only process the n first somethings.

=item B<-e, --every>

Process every x record. E.g. every 5th record.

=item B<-v --verbose>

More verbose output.

=item B<-d --debug>

Even more verbose output.

=item B<-h, -?, --help>

Prints this help message and exits.

=back
                                                               
=cut
 
sub get_options {
 
    # Options
    my $config_dir  = '';
    my $limit       = 0;
    my $every       = '';
    my $verbose     = '';
    my $debug       = '';
    my $help        = '';
 
    GetOptions (
        'c|config=s'  => \$config_dir,
        'l|limit=i'   => \$limit,
        'e|every=i'   => \$every,
        'v|verbose'   => \$verbose,
        'd|debug'     => \$debug,
        'h|?|help'    => \$help
    );
 
    pod2usage( -exitval => 0 ) if $help;
    pod2usage( -msg => "\nMissing Argument: -c, --config required\n",  -exitval => 1 ) if !$config_dir;
 
    return ( $config_dir, $limit, $every, $verbose, $debug );
 
}

## Internal subroutines.

# If these are needed elswhere they should be moved to some kind of include.

# Takes: YYYYMMDD
# Returns: YYYY-MM-DD

sub _fix_date {

    my ( $d ) = @_;
    if ( $d && length $d == 8 ) {
        $d =~ m/(\d{4})(\d{2})(\d{2})/;
        return "$1-$2-$3";
    } else {
        return '';
    }

}

sub fix_date {

    my ( $d ) = @_;
    my $year  = substr $d, 0, 4;
    my $month = substr $d, 4, 2;
    my $day   = substr $d, 6, 2;
    return "$year-$month-$day";

}

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
