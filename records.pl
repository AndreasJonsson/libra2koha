#!/usr/bin/env perl

# Copyright 2015 Magnus Enger Libriotech

=head1 NAME

records.pl - Read MARCXML records from a file and add items from the database.

=head1 SYNOPSIS

 perl records.pl -v --config /home/my/library/

=cut

use MARC::File::XML ( BinaryEncoding => 'utf8', RecordFormat => 'NORMARC' );
use DBI;
use Getopt::Long;
use YAML::Syck qw( LoadFile );
use Term::ProgressBar;
use Data::Dumper;
use Template;
use DateTime;
use Pod::Usage;
use Modern::Perl;
use Data::Dumper;
use Itemtypes;
use ExplicitRecordNrField;

binmode STDOUT, ":utf8";
$|=1; # Flush output

# Get options
my ( $config_dir, $input_file, $flag_done, $limit, $every, $verbose, $debug, $explicit_record_id ) = get_options();

=head1 CONFIG FILES

Config files should be kept in one directory and pointed to by the -c or
--config option. Different config files are expected to have specific names, as
detailed below.

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

=head2 loc.yaml

Mapping from LocalShelfs in Libra to LOC authorized values and 952$c in Koha.
Have a look at LocalShelfs.txt in the exported data to get an idea of what
should go into this mapping.

=cut

my $loc;
if ( -f $config_dir . '/loc.yaml' ) {
    $loc = LoadFile( $config_dir . '/loc.yaml' );
}

=head2 ccode.yaml

Mapping from Departments in Libra to CCODE authorised values in Koha.

To generate a skeleton for this file:

  perl table2config.pl /path/to/Departments.txt 0 2

=cut

my $ccode;
if ( -f $config_dir . '/ccode.yaml' ) {
    $ccode = LoadFile( $config_dir . '/ccode.yaml' );
}

# Check that the input file exists
if ( !-e $input_file ) {
    print "The file $input_file does not exist...\n";
    exit;
}

$limit = num_records_($input_file) if $limit == 0;
my $progress = Term::ProgressBar->new( $limit );

# Set up the database connection
my $dbh = DBI->connect( $config->{'db_dsn'}, $config->{'db_user'}, $config->{'db_pass'}, { RaiseError => 1, AutoCommit => 1 } );

# Query for selecting items connected to a given record

my $sth;
unless ($explicit_record_id) {
    $sth = $dbh->prepare( <<'EOF' );
    SELECT Items.*, BarCodes.BarCode
    FROM exportCatMatch, Items, BarCodes
    WHERE exportCatMatch.ThreeOne = ?
      AND exportCatMatch.IdCat = Items.IdCat
      AND Items.IdItem = BarCodes.IdItem
EOF
} else {
    $sth = $dbh->prepare( <<'EOF' );
    SELECT Items.*, BarCodes.BarCode
    FROM Items, BarCodes
    WHERE Items.IdCat = ?
      AND Items.IdItem = BarCodes.IdItem
EOF
}

# Query for setting done = 1 if --flag_done is set
my $sth_done = $dbh->prepare("
    UPDATE Items SET done = 1 WHERE IdItem = ?
");

# Create a file output object
my $file = MARC::File::XML->out( $output_file );

=head1 PROCESS RECORDS

Record level actions

=cut

say "Starting record iteration" if $verbose;
my $batch = MARC::File::XML->in( $input_file );
my $count = 0;
my $count_items = 0;
RECORD: while (my $record = $batch->next()) {

    # Only do every x record
    if ( $every && ( $count % $every != 0 ) ) {
        $count++;
        next RECORD;
    }

    my $last_itemtype;

    $record->encoding( 'UTF-8' );
    say '* ' . $record->title() if $verbose;

=head2 Record level changes

=head3 Move 976b to 653

The records from Libra.se have subjects in 976b, we'll move them to 653

=cut

    if ( $record->field( '976' ) ) {
        my @f976s = $record->field( '976' );
        foreach my $f976 ( @f976s ) {
            if ( $f976->subfield( 'b' ) ) {
                my $field653 = MARC::Field->new( 653, ' ', ' ',
                  'a' => $f976->subfield( 'b' ),
                );
                $record->insert_fields_ordered( $field653 );
                $record->delete_fields( $f976 );
            }
        }
    }

=head2 Add item level information in 952

Build up new items in 952.

Comments in quotes below are taken from this document:
L<http://wiki.koha-community.org/wiki/Holdings_data_fields_%289xx%29>

=cut

    my $items;
    my $recordid;

    unless ($explicit_record_id) {
        next RECORD unless $record->field( '001' ) && $record->field( '003' );
        # Get the record ID from 001 and 003
        my $f001 = $record->field( '001' )->data();
        my $f003 = lc $record->field( '003' )->data();
        my $recordid = lc "$f003$f001";
        # Remove any non alphanumerics
        $recordid =~ s/[^a-zæøåöA-ZÆØÅÖ\d]//g;
        say "$f003 + $f001 = $recordid" if $verbose;
        # Look up items by recordid in the DB and add them to our record
        $sth->execute( $recordid );
        $items = $sth->fetchall_arrayref({});
    } else {
        my $f = $record->field( $ExplicitRecordNrField::RECORD_NR_FIELD );

        die "Explicit record nr field is missing!" unless defined $f;

        $recordid = $f->subfield( $ExplicitRecordNrField::RECORD_NR_SUBFIELD );

        die "Explicit record nr subfield is missing!" unless defined $recordid;

        $sth->execute( $recordid );

        $items = $sth->fetchall_arrayref({});

        $record->delete_fields( $f );
    }
    ITEM: foreach my $item ( @{ $items } ) {

        say Dumper $item if $debug;

=head3 952$a and 952$b Homebranch and holdingbranch (mandatory)

"Code must be defined in System Administration > Libraries, Branches and Groups."

=cut

        my $field952 = MARC::Field->new( 952, ' ', ' ',
          'a' => $branchcodes->{ $item->{'IdBranchCode'} }, # Homebranch
          'b' => $branchcodes->{ $item->{'IdBranchCode'} }, # Holdingbranch
        );

	say Dumper $field952 if $debug;

=head3 952$c Shelving location

"Coded value, matching the authorized value list 'LOC'."

Stored in Items.IdLocalShelf and references the LocalShelfs table. SQL to check
which values are actually in use:

  select IdLocalShelf, count(*) from Items group by IdLocalShelf

=cut

        # $field952->add_subfields( 'c', $item->{'IdDepartment'} ) if $item->{'IdDepartment'};
        $field952->add_subfields( 'c', $loc->{ $item->{'IdLocalShelf'} } ) if $item->{'IdLocalShelf'};

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
        if ( defined($item->{'Location_Marc'}) && length($item->{'Location_Marc'}) > 1) {
            $field952->add_subfields( 'o', $item->{'Location_Marc'} );
        } else {
            my $field852 = $record->field( '852' );
            if (defined $field852) {
                my $s = '';
                foreach my $sf ($field852->subfields()) {
                    $s .= $sf->[1];
                }
                $field952->add_subfields( 'o', $s );
            } else {
                say STDERR "Didn't add any 952 o) to record $recordid!";
            }
        }

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

The Info column seems to contain some weird non-printing char. We work around
this by checking for length greater than 1.

=cut

        if ( defined $item->{'Info'} && length $item->{'Info'} > 1 ) {
            $field952->add_subfields( 'x', $item->{'Info'} ) if $item->{'Info'} ne ' ';
        }

=head3 952$y Itemtype (mandatory)

lib/Itemtype.pm is pulled in and the subroutine C<get_itemtype()> is used to
determin the itemtype of a given record. This subroutine might need editing for
different libraries.

A separate script, called F<itemtypes.pl>, can be used to assess the results
from C<get_itemtype()>. It will ingest the same raw MARCXML data asthe current
script and output the number of occurences for each itemtype, with or without
debug output. Run C<perldoc itemtypes.pl> for more documentation.

=cut

        my $itemtype = get_itemtype( $record );
        $field952->add_subfields( 'y', $itemtype );
        $last_itemtype = $itemtype;

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

        # 1 = Försvunna
        if ( $item->{'IdStatusCode'} == 1 ) {
            $field952->add_subfields( '1', 'FORSVUNNEN' );
        }
        # 2 = Bokvård
        elsif ( $item->{'IdStatusCode'} == 2 ) {
            $field952->add_subfields( '4', 'BOKVARD' );
        }
        # 3 = Osprättade
        elsif ( $item->{'IdStatusCode'} == 3 ) {
            $field952->add_subfields( 'x', 'Osprättad' );
        }
        # 4 = till översättning
        elsif ( $item->{'IdStatusCode'} == 3 ) {
            $field952->add_subfields( 'x', 'till översättning' );
        }


=head3 952$7 Not for loan

TODO Unused

=cut

        # $field952->add_subfields( 'd', $item->{''} ) if $item->{''};

=head3 952$8 Collection code

Values must be defined in the CCODE authorized values category.

We base this on the Departments table and the value of Items.IdDepartment value.

=cut

        $field952->add_subfields( '8', $ccode->{ $item->{'IdDepartment'} } ) if $item->{'IdDepartment'};


        # Add the field to the record
        $record->insert_fields_ordered( $field952 );

        # Mark the item as done, if we are told to do so
        if ( $flag_done ) {
            $sth_done->execute( $item->{'IdItem'} );
        }

        $count_items++;

    } # end foreach items

=head2 Add 942

Just add the itemtype in 942$c.

=cut

    if ( $last_itemtype ) {
        my $field942 = MARC::Field->new( 942, ' ', ' ', 'c' => $last_itemtype );
        $record->insert_fields_ordered( $field942 );
    }

    $file->write( $record );
    say MARC::File::XML::record( $record ) if $debug;

    # Count and cut off at the limit if one is given
    $count++;
    $progress->update( $count );
    last if $limit && $limit == $count;

} # end foreach record

$progress->update( $limit );

say "$count records, $count_items items done";
say "Did you remember to load data into memory?" if $count_items == 0;

=head1 OPTIONS

=over 4

=item B<-c, --config>

Path to directory that contains config files. See the section on
L</"CONFIG FILES"> above for more details.

=item B<-i, --infile>

Path to MARCXML input file. (The path to the MARCXML output file is set in
F<config.yaml>.)

=item B<-f, --flag_done>

Flag items that have been done as such in the database. This requires the
following alteration to the database (libra2koha.sh will do this for you, if you
use it):

  ALTER TABLE Items ADD COLUMN done INT(1) DEFAULT 0;

If --flag_done is set, items that have been connected to records will have the
value of _done updated to 1. After this script has run, items that have not been
connected to records can be found like this:

  SELECT * FROM Items WHERE done = 0;

If this script needs to be run multiple times, the done column should be reset
to 0 with this:

  UPDATE Items SET done = 0;

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
    my $config_dir         = '';
    my $input_file         = '';
    my $flag_done          = '';
    my $explicit_record_id = 0;
    my $limit              = 0;
    my $every              = '';
    my $verbose            = '';
    my $debug              = '';
    my $help               = '';

    GetOptions (
        'c|config=s'           => \$config_dir,
        'i|infile=s'           => \$input_file,
        'f|flag_done'          => \$flag_done,
        'l|limit=i'            => \$limit,
        'e|every=i'            => \$every,
        'E|explicit-record-id' => \$explicit_record_id,
        'v|verbose'            => \$verbose,
        'd|debug'              => \$debug,
        'h|?|help'             => \$help
    );

    pod2usage( -exitval => 0 ) if $help;
    pod2usage( -msg => "\nMissing Argument: -c, --config required\n",  -exitval => 1 ) if !$config_dir;
    pod2usage( -msg => "\nMissing Argument: -i, --infile required\n",  -exitval => 1 ) if !$input_file;

    return ( $config_dir, $input_file, $flag_done, $limit, $every, $verbose, $debug, $explicit_record_id );

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

sub num_records_ {
    $input_file = shift;
    my $batch = MARC::File::XML->in( $input_file );
    my $n = 0;
    while ($batch->next()) {
        $n++;
    }
    return $n;
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
