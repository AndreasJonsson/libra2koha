#!/usr/bin/perl 
 
# Copyright 2015 Magnus Enger Libriotech
 
=head1 NAME

records.pl - Read MARCXML records from a file and add items from the database.

=head1 SYNOPSIS

 perl records.pl -v

=cut

use MARC::File::XML ( BinaryEncoding => 'utf8', RecordFormat => 'NORMARC' );
use DBI;
use Getopt::Long;
use YAML::Syck qw( LoadFile );
use Data::Dumper;
use Template;
use DateTime;
use Pod::Usage;
use Modern::Perl;
use Data::Dumper;

binmode STDOUT, ":utf8";
$|=1; # Flush output
    
# Get options
my ( $input_file, $limit, $verbose, $debug ) = get_options();

=head1 CONFIG FILES

=head2 config.yaml

The main configuration file. Contains things like username and password for 
connecting to the database. 

See config-sample.yaml for an example. 

=cut

my $config;
if ( -f 'config.yaml' ) {
    $config = LoadFile( 'config.yaml' );
}

=head2 branchcodes.yaml

Mapping from Branches.IdBRanchCode in Libra to branchcodes in Koha. 

=cut

my $branchcodes;
if ( -f 'branchcodes.yaml' ) {
    $branchcodes = LoadFile( 'branchcodes.yaml' );
}

# Check that the input file exists
if ( !-e $input_file ) {
    print "The file $input_file does not exist...\n";
    exit;
}

# Set up the database connection
my $dbh = DBI->connect( $config->{'db_dsn'}, $config->{'db_user'}, $config->{'db_pass'}, { RaiseError => 1, AutoCommit => 1 } );
my $sth = $dbh->prepare("
    SELECT Items.*, BarCodes.BarCode 
    FROM exportCatMatch, Items, BarCodes 
    WHERE exportCatMatch.ThreeOne = ? 
      AND exportCatMatch.IdCat = Items.IdCat 
      AND Items.IdItem = BarCodes.IdItem
");

say MARC::File::XML::header();

=head1 PROCESS RECORDS

Record level actions

=cut

say "Starting record iteration" if $verbose;
my $batch = MARC::File::XML->in( $input_file );
my $count = 0;
RECORD: while (my $record = $batch->next()) {

    $record->encoding( 'UTF-8' );
    say "<!-- " . $record->title()  . " -->" if $verbose;

=head2 Add item level information in 952

Build up new items in 952.

Comments in quotes below are taken from this document:
L<http://wiki.koha-community.org/wiki/Holdings_data_fields_%289xx%29>

=cut

    next RECORD unless $record->field( '001' ) && $record->field( '003' );
    # Get the record ID from 001 and 003
    my $f001 = $record->field( '001' )->data();
    my $f003 = $record->field( '003' )->data();
    if ( $f003 eq 'S' ) {
        $f003 = 'swlnbt';
    }
    my $recordid = lc "$f003$f001";
    say "$f003 + $f001 = $recordid" if $verbose;
    # Look up items by recordid in the DB and add them to our record
    $sth->execute( $recordid );
    my $items = $sth->fetchall_arrayref({});
    ITEM: foreach my $item ( @{ $items } ) {

        say Dumper $item if $debug;

=head3 952$a and 952$b Homebranch and holdingbranch (mandatory)

"Code must be defined in System Administration > Libraries, Branches and Groups."

=cut

        my $field952 = MARC::Field->new( 952, ' ', ' ',
          'a' => $branchcodes->{ $item->{'IdBranchCode'} }, # Homebranch
          'b' => $branchcodes->{ $item->{'IdBranchCode'} }, # Holdingbranch
        );

=head3 952$c Shelving location

"Coded value, matching the authorized value list 'LOC'."

=cut

        $field952->add_subfields( 'c', $item->{'IdDepartment'} ) if $item->{'IdDepartment'};

=head3 952$d Date acquired

YYYY-MM-DD

=cut

        $field952->add_subfields( 'd', fix_date( $item->{'RegDate'} ) ) if $item->{'RegDate'};

=head3 952$g  Purchase price + 952$v Replacement price

To see which prices occur in the data:

  SELECT Price, count(*) AS count FROM Items WHERE Price != 0 GROUP BY price;

=cut

        $field952->add_subfields( 'g', $item->{'Price'} ) if $item->{'Price'};
        $field952->add_subfields( 'v', $item->{'Price'} ) if $item->{'Price'};

=head3 952$l Total Checkouts

"Total number of checkouts. Display only field."

=cut

        $field952->add_subfields( 'l', $item->{'NoOfLoansTot'} ) if $item->{'NoOfLoansTot'};
        
=head3 952$o Call number

To see what is present in the data:

  SELECT Location_Marc, count(*) AS count FROM Items GROUP BY Location_Marc;

=cut

        $field952->add_subfields( 'o', $item->{'Location_Marc'} ) if $item->{'Location_Marc'};

=head3 952$p Barcode (mandatory)

From BarCodes.Barcode.

=cut

    $field952->add_subfields( 'p', $item->{'BarCode'} ) if $item->{'BarCode'};

=head3 952$r Date last seen

"The date that the item was last seen in the library (checked in / checked out
 / inventoried)."

=cut

        if ( $item->{'LatestLoanDate'} ne '' && $item->{'LatestReturnDate'} ne '' && $item->{'LatestLoanDate'} > $item->{'LatestReturnDate'} ) {
            $field952->add_subfields( 'r', $item->{'LatestLoanDate'} ) if $item->{'LatestLoanDate'};
        } elsif ( $item->{'LatestReturnDate'} ne '' ) {
            $field952->add_subfields( 'r', fix_date( $item->{'LatestReturnDate'} ) ) if $item->{'LatestReturnDate'};
        } elsif ( $item->{'LatestLoanDate'} ne '' ) {
            $field952->add_subfields( 'r', fix_date( $item->{'LatestLoanDate'} ) ) if $item->{'LatestLoanDate'};
        }

=head3 952$s Date last checked out

"Last checkout date of item. Display only field."

=cut

        $field952->add_subfields( 's', fix_date( $item->{'LatestLoanDate'} ) ) if $item->{'LatestLoanDate'};

=head3 952$x     Non-public note

"Internal staff note."

To see what is present in the data:

  SELECT Info, COUNT(*) FROM Items WHERE Info != '' GROUP BY Info;

=cut

        if ( length $item->{'Info'} > 1 ) {
            $field952->add_subfields( 'x', $item->{'Info'} ) if $item->{'Info'} ne ' ';
        }

=head3 952$y Itemtype (mandatory)

TODO Uses the mapping in itemtypes.yaml.

=cut

        # FIXME Just add a dummy value for now
        $field952->add_subfields( 'y', 'X' );
        # $last_itemtype = $itemtype;

=head3 952$1 Lost status

"Status of the item, connect with the authorised values list 'LOST'"

To see what codes are available in Libra:

  SELECT IdStatusCode, StatusCode, Name FROM StatusCodes;

To see what codes are used in the items:

  SELECT IdStatusCode, COUNT(*) FROM Items GROUP BY IdStatusCode;

How often the codes are used, with names:

  SELECT Items.IdStatusCode, StatusCodes.Name, COUNT(*) AS count
  FROM Items, StatusCodes
  WHERE Items.IdStatusCode = StatusCodes.IdStatusCode
  GROUP BY Items.IdStatusCode;

FIXME This should be done with a mapping file!

=cut

        # TODO
        # $field952->add_subfields( '1', '1' ) if $item->{'IdStatusCode'} == 2;

=head3 952$7 Not for loan

TODO

=cut

        # $field952->add_subfields( 'd', $item->{''} ) if $item->{''};

=head3 952$8 Collection code

Values must be defined in the CCODE authorized values category.

=cut

        $field952->add_subfields( '8', 'FIXME' );


        # Add the field to the record
        $record->insert_fields_ordered( $field952 );

    } # end foreach items

=head2 Add 942

Just add the itemtype in 942$c.

=cut

    # FIXME my $field942 = MARC::Field->new( 942, ' ', ' ', 'c' => $last_itemtype );
    # $record->insert_fields_ordered( $field942 );

    say MARC::File::XML::record( $record );
    
    # Count and cut off at the limit if one is given
    $count++;
    last if $limit && $limit == $count;

} # end foreach record

say MARC::File::XML::footer();

# Read MARC records
 
=head1 OPTIONS

=over 4

=item B<-i, --infile>

Name of input file.

=item B<-l, --limit>

Only process the n first somethings.

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
    my $input_file = '';
    my $limit      = '', 
    my $verbose    = '';
    my $debug      = '';
    my $help       = '';
 
    GetOptions (
        'i|infile=s' => \$input_file,
        'l|limit=i'  => \$limit,
        'v|verbose'  => \$verbose,
        'd|debug'    => \$debug,
        'h|?|help'   => \$help
    );
 
    pod2usage( -exitval => 0 ) if $help;
    pod2usage( -msg => "\nMissing Argument: -i, --infile required\n", -exitval => 1 ) if !$input_file;
 
    return ( $input_file, $limit, $verbose, $debug );
 
}

## Internal subroutines.

# If these are needed elswhere they should be moved to some kind of include.

# Takes: YYYYMMDD
# Returns: YYYY-MM-DD

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
