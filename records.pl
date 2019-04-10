#!/usr/bin/env perl

# Copyright 2015 Magnus Enger Libriotech
# Copyright 2017 Andreas Jonsson, andreas.jonsson@kreablo.se

=head1 NAME

records.pl - Read MARCXML records from a file and add items from the database.

=head1 SYNOPSIS

 perl records.pl -v --config /home/my/library/

=cut

use MARC::File::USMARC;
use MARC::File::XML ( BinaryEncoding => 'utf8', RecordFormat => 'MARC21' );
use MARC::Batch;
use DBI;
use Getopt::Long::Descriptive;
use YAML::Syck qw( LoadFile );
use Term::ProgressBar;
use Data::Dumper;
use Template;
use DateTime;
use Pod::Usage;
use Modern::Perl;
use Itemtypes;
use ExplicitRecordNrField;
use MarcUtil::WrappedMarcMappingCollection;
use StatementPreparer;
use TimeUtils;
use utf8;

binmode STDOUT, ":utf8";
$|=1; # Flush output

$YAML::Syck::ImplicitUnicode = 1;

open IGNORED_BIBLIOS, ">ignored_biblios.txt";

# Get options

my ($opt, $usage) = describe_options(
    '%c %o <some-arg>',
    [ 'config=s', 'config directory', { required => 1 } ],
    [ 'batch=i', 'batch number', { required => 1 } ],
    [ 'infile=s', 'input file', { required => 1 } ],
    [ 'default-branchcode=s', 'Default branchcode', { default => '' } ],
    [ 'outputdir=s', 'output directory', { required => 1 } ],
    [ 'flag-done', 'Use item done flag', { default => 0 } ],
    [ 'limit=i', 'Limit processing to this number of items.  0 means process all.', { default => 0 } ],
    [ 'every=i', 'Process every nth item', { default => 1 } ],
    [ 'explicit-record-id', 'Use explicit record ids', { default => 0 }],
    [ 'format=s', 'Input database format', { required => 1 }],
    [ 'xml-input', 'Expect XML input', { default => 0 }],
    [ 'xml-output', 'Generate XML output', { default => 0 }],
    [],
    [ 'verbose|v',  "print extra stuff"            ],
    [ 'debug',      "Enable debug output" ],
    [ 'help',       "print usage message and exit", { shortcircuit => 1 } ],
);

if ($opt->help) {
    print $usage->text;
    exit 0;
}

my $config_dir = $opt->config;
my $limit = $opt->limit;
my $output_dir = $opt->outputdir;
my $input_file = $opt->infile;
my $format = $opt->format;

sub add_stat {
    my ($stat, $item, $extra) = @_;
    unless (defined ($stat->{$item})) {
	$stat->{$item} = {
	    count => 1
	}
    } else {
	$stat->{$item}->{count}++;
    }
    if (defined($extra)) {
	unless ($stat->{$item}->{extra}) {
	    $stat->{$item}->{extra} = {};
	}
	add_stat($stat->{$item}->{extra}, $extra);
    }
}
my %itemtype_stats = ();
sub add_itemtype_stat  {
    my $itemtype = shift;
    my $extra = shift;
    add_stat(\%itemtype_stats, $itemtype, $extra);
}
my %catid_types = ();
sub add_catitem_stat {
    my $catid = shift;
    add_stat(\%catid_types, $catid);
}

my $mmc = MarcUtil::WrappedMarcMappingCollection::marc_mappings(
    'isbn'                             => { map => { '020' => 'a' } },
    'issn'                             => { map => { '022' => 'a' } },
    'catid'                            => { map => { '035' => 'a' } },
    'klassifikationskod'               => { map => { '084' => 'a' } },
    'klassifikationsdel_av_uppställningssignum' => { map => { '852' => 'h' } },
    'beståndsuppgift'                  => { map => { '866' => 'a' } },
    'okontrollerad_term'               => { map => { '653' => 'a' } },
    'fysisk_beskrivning'               => { map => { '300' => 'e' } },
    'genre_form_uppgift_eller_fokusterm' => { map => { '655' => 'a' } },
    'homebranch'                       => { itemcol => 'homebranch', map => { '952' => 'a' } },
    'holdingbranch'                    => { itemcol => 'holdingbranch', map => { '952' => 'b' } },
    'localshelf'                       => { itemcol => 'location', map => { '952' => 'c' } },
    'date_acquired'                    => { itemcol => 'dateaccessioned', map => { '952' => 'd' } },
    'price'                            => { numeric => 1, itemcol => ['price', 'replacementprice'],  map => { '952' => [ 'g', 'v' ] } },
    'total_number_of_checkouts'        => { numeric => 1, itemcol => 'issues', map => { '952' => 'l' } },
    'call_number'                      => { itemcol => 'itemcallnumber', map => { '952' => 'o' } },
    'barcode'                          => { itemcol => 'barcode', map => { '952' => 'p' } },
    'date_last_seen'                   => { itemcol => 'datelastseen', map => { '952' => 'r' } },
    'date_last_checkout'               => { itemcol => 'datelastborrowed', map => { '952' => 's' } },
    'internal_staff_note'              => { itemcol => 'itemnotes_nonpublic', map => { '952' => 'x' } },
    'itemtype'                         => { itemcol => 'itype', map => { '952' => 'y' } },
    'lost_status'                      => { itemcol => 'itemlost', av => 'LOST', map => { '952' => '1' } },
    'damaged_status'                   => { itemcol => 'damaged', av => 'DAMAGED', map => { '952' => '4' } },
    'not_for_loan'                     => { itemcol => 'notforloan', av=> 'NOT_LOAN', map => { '952' => '7' } },
    'collection_code'                  => { itemcol => 'ccode', map => { '952' => '8' } },
    'subjects'                         => { map => { '653' => 'b' } },
    'libra_subjects'                   => { map => { '976' => 'b' } },
    'biblioitemtype'                    => { map => { '942' => 'c' }, append => 0 }
    );


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
my $output_file = $output_dir ? "$output_dir/records.marc" : $config->{'output_marc'};

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

my $notforloan = {};
if ( -f $config_dir . '/notforloan.yaml' ) {
    $notforloan = LoadFile( $config_dir . '/notforloan.yaml');
}

my $damaged = {};
if ( -f $config_dir . '/damaged.yaml' ) {
    $damaged = LoadFile( $config_dir . '/damaged.yaml');
}

my $lost = {};
if ( -f $config_dir . '/lost.yaml' ) {
    $lost = LoadFile( $config_dir . '/lost.yaml');
}

my @input_files = glob $input_file;
# Check that the input file exists
if (  scalar(@input_files) < 1 ) {
    print "The file $input_file does not exist...\n";
    exit;
}

#$limit = 33376;
$limit = num_records_($input_file) if $limit == 0;

print "There are $limit records in $input_file\n";

my $progress = Term::ProgressBar->new( $limit );

# Set up the database connection
my $dbh = DBI->connect( $config->{'db_dsn'}, $config->{'db_user'}, $config->{'db_pass'}, { RaiseError => 1, AutoCommit => 1 } );
$mmc->quote(sub { return $dbh->quote(shift); });

# Query for selecting items connected to a given record

my $sth;

my $isbn_issn_sth;
if ($format eq 'bookit') {
    $isbn_issn_sth  = $dbh->prepare("INSERT INTO catalog_isbn_issn (CA_CATALOG_ID, isbn, issn) VALUES (?, ?, ?)");
}

my $is_documentgroup_sth;
if ($format eq 'micromarc') {
    $is_documentgroup_sth  = $dbh->prepare("SELECT EXISTS (SELECT * FROM caMarcRecord WHERE  caMarcRecord.Id = ? AND (DocumentGroupId = 4 OR DocumentGroupId = 5))");
}

my $has_ca_catalog = 1;

my $preparer = new StatementPreparer(format => $format, dbh => $dbh);

my $item_context = {
    batch => $opt->batch,
    items => []
};
my $batchno = $opt->batch;

open ITEM_OUTPUT, ">:utf8", "$output_dir/items.sql" or die "Failed to open $output_dir/items.sql: $!";

print ITEM_OUTPUT <<EOF;
CREATE TABLE IF NOT EXISTS k_items_idmap (
    original_id INT PRIMARY KEY,
    itemnumber INT UNIQUE,
    batch INT,
    FOREIGN KEY (itemnumber) REFERENCES items(itemnumber) ON DELETE CASCADE ON UPDATE CASCADE
);
EOF

unless ($opt->explicit_record_id) {
    if ($has_ca_catalog) {
	$sth = $preparer->prepare('items_ca');
    } else {
	$sth = $dbh->prepare( <<'EOF' );
    SELECT Items.*, BarCodes.BarCode
    FROM exportCatMatch, Items, BarCodes
    WHERE exportCatMatch.ThreeOne = ?
      AND exportCatMatch.IdCat = Items.IdCat
      AND Items.IdItem = BarCodes.IdItem
EOF
    }
} else {
    $sth = $dbh->prepare( <<'EOF' );
    SELECT Items.*, BarCodes.BarCode
    FROM Items, BarCodes
    WHERE Items.IdCat = ?
      AND Items.IdItem = BarCodes.IdItem
EOF
}

# Query for setting done = 1 if --flag_done is set
#my $sth_done = $dbh->prepare("
#    UPDATE Items SET done = 1 WHERE IdItem = ?
#");

# Create a file output object
my $file;
if ($opt->xml_output) {
    $file = MARC::File::XML->out( $output_file );
} else {
    open $file, ">:raw:utf8", $output_file or die "Failed to open '$output_file': $!";
}

# Configure Template Toolkit
my $ttconfig = {
    INCLUDE_PATH => '', 
    ENCODING => 'utf8'  # ensure correct encoding
};
binmode( STDOUT, ":utf8" );
# create Template object
my $tt2 = Template->new( $ttconfig ) || die Template->error(), "\n";

=head1 PROCESS RECORDS

Record level actions

=cut

my $count = 0;
my $count_items = 0;
say "Starting record iteration" if $opt->verbose;
for my $marc_file (glob $input_file) {
    my $batch;
    if ($opt->xml_input) {
	$batch = MARC::Batch->new( 'XML', $marc_file );
    } else {
	$batch = MARC::File::USMARC->in( $marc_file );
    }
  RECORD: while (my $record = $batch->next()) {

      # Only do every x record
      if ( $opt->every && ( $count % $opt->every != 0 ) ) {
	  $count++;
	  next RECORD;
      }

      $mmc->record($record);

      my $last_itemtype;

      $record->encoding( 'UTF-8' );
      say '* ' . $record->title() if $opt->verbose;

=head2 Record level changes

=head3 Missing 003

=cut

      #if (!defined($record->field('003'))) {
      #my $field = MARC::Field->new( '003', $default_branchcode );
      #$record->insert_fields_ordered($field);
      #}

=head3 ISBN and ISSN and 081 a

Bookit format ISBN is in  350 00 c and ISSN in 350 10 c

=cut
      if ($format eq 'bookit') {
	  my $first_isbn;
	  my $first_issn;
	  for my $f350 ($record->field('350')) {
	      if ($f350->indicator(1) == 0) {
		  my $isbn = $f350->subfield('c');
		  if (defined($isbn)) {
		      if (!defined($first_isbn)) {
			  $first_isbn = $isbn;
		      }
		      $mmc->set('isbn', $isbn);
		      $record->delete_fields( $f350 );
		  }
	      } elsif ($f350->indicator(1) == 1) {
		  my $issn = $f350->subfield('c');
		  if (defined($issn)) {
		      if (!defined($first_issn)) {
			  $first_issn = $issn;
		      }
		      $mmc->set('issn', $issn);
		      $record->delete_fields( $f350 );
		  }
	      }
	  }
	  $isbn_issn_sth->execute(int($record->field( '001' )->data()), $first_isbn, $first_issn)
	      or warn "Failed to insert isbn '$first_isbn' and issn '$first_issn'!";
	  for my $f081 ($record->field('081')) {
	      my $signum = $f081->subfield('h');
	      if (defined($signum)) {
		  $mmc->set('klassifikationsdel_av_uppställningssignum', $signum);
		  $record->delete_fields( $f081 );
	      }
	  }
      }

=head3 Move 976b to 653

The records from Libra.se have subjects in 976b, we'll move them to 653

=cut
      $mmc->set('subjects', $mmc->get('libra_subjects'));
      $mmc->delete('libra_subjects');

=head2 Add item level information in 952

Build up new items in 952.

Comments in quotes below are taken from this document:
L<http://wiki.koha-community.org/wiki/Holdings_data_fields_%289xx%29>

=cut

      my $items;
      my $recordid;

      unless ($opt->explicit_record_id) {
	  my $catid;
	  for my $cid ($mmc->get('catid')) {
	      if (defined($cid) and $cid =~ /^\(LibraSE\)/) {
		  $cid =~ s/\((.*)\)//;
		  $catid = $cid;
		  last;
	      }
	  }
	  # Get the record ID from 001 and 003
	  my $f001 = $record->field( '001' )->data();
	  $item_context->{marc001} = $dbh->quote($f001);
	  my $f003;
	  my $recordid;
	  unless ($record->field( '003' )) {
	      warn 'Record does not have 003! catid: ' . $catid . ' default to ';
	      $f003 = '';
	      $item_context->{marc003} = 'NULL';
	  } else {
	      $f003 = lc $record->field( '003' )->data();
	      $f003 =~ s/[^a-zæøåöA-ZÆØÅÖ\d]//g;
	      $item_context->{marc003} = $dbh->quote($f003);
	  }
	  if ($format eq 'libra') {
	      say STDERR "Record does not have 001 and 003!", next RECORD unless $f001 && $f003;
	      $recordid = lc "$f003$f001";
	  } else {
	      say STDERR "Record does not have 001!", next RECORD unless $f001;
	      $recordid = $f001;
	  }
	  # Remove any non alphanumerics
	  $recordid =~ s/[^a-zæøåöA-ZÆØÅÖ\d]//g;
	  say "catid: $catid" if $opt->verbose;
	  # add_catitem_stat($catid);
	  # Look up items by recordid in the DB and add them to our record
	  if ($format eq 'micromarc') {
	      $is_documentgroup_sth->execute( $recordid );
	      my @process = $is_documentgroup_sth->fetchrow_array;
	      my ($process) = @process;
	      if (!$process) {
		  next RECORD;
	      }
	      $sth->execute( $recordid ) or die "Failed to query items for $recordid";
	  } else {
	      $sth->execute( $recordid, $catid ) or die "Failed to query items for $recordid";
	  }

	  # $items = $sth->fetchall_arrayref({});
      } else {
	  my $f = $record->field( $ExplicitRecordNrField::RECORD_NR_FIELD );

	  die "Explicit record nr field is missing!" unless defined $f;

	  $recordid = $f->subfield( $ExplicitRecordNrField::RECORD_NR_SUBFIELD );

	  die "Explicit record nr subfield is missing!" unless defined $recordid;

	  $sth->execute( $recordid );

	  # $items = $sth->fetchall_arrayref({});

      }
      
      my $includedItem = 0;
      my $ignoredItem = 0;

    ITEM: while (my $item = $sth->fetchrow_hashref) {
        say Dumper $item if $opt->debug;

	$mmc->new_item($item->{'IdItem'});

	if ($branchcodes->{$item->{'IdBranchCode'}} eq '') {
	    $ignoredItem++;
	    next ITEM;
	}

=head3 952$a and 952$b Homebranch and holdingbranch (mandatory)

"Code must be defined in System Administration > Libraries, Branches and Groups."

=cut

        $mmc->set('homebranch',    $branchcodes->{$item->{'IdBranchCode'}} );
        $mmc->set('holdingbranch', $branchcodes->{defined($item->{'IdPlacedAtBranchCode'}) ? $item->{'IdPlacedAtBranchCode'} : $item->{'IdBranchCode'}});


=head3 952$c Shelving location

"Coded value, matching the authorized value list 'LOC'."

Stored in Items.IdLocalShelf and references the LocalShelfs table. SQL to check
which values are actually in use:

  select IdLocalShelf, count(*) from Items group by IdLocalShelf

=cut

	my $localshelf;
	if (defined($item->{'LocalShelf'})) {
	    $localshelf = $item->{'LocalShelf'};
	    $mmc->set('localshelf', $localshelf);
	} elsif (defined($item->{'IdLocalShelf'})) {
	    # $field952->add_subfields( 'c', $item->{'IdDepartment'} ) if $item->{'IdDepartment'};
	    $localshelf = $loc->{ $item->{'IdLocalShelf'} };
	    $mmc->set('localshelf', $localshelf);
	}

=head3 952$d Date acquired

YYYY-MM-DD

=cut

        $mmc->set( 'date_acquired', fix_date( $item->{'RegDate'} ) ) if $item->{'RegDate'};

=head3 952$g  Purchase price + 952$v Replacement price

To see which prices occur in the data:

  SELECT Price, count(*) AS count FROM Items WHERE Price != 0 GROUP BY price;

=cut

	$mmc->set('price', $item->{'Price'})  if $item->{'Price'};

=head3 952$l Total Checkouts

"Total number of checkouts. Display only field."

=cut

        $mmc->set('total_number_of_checkouts', $item->{'NoOfLoansTot'} ) if (defined($item->{'NoOfLoansTot'}));

=head3 952$o Call number

To see what is present in the data:

  SELECT Location_Marc, count(*) AS count FROM Items GROUP BY Location_Marc;

=cut
        # if ( defined($item->{'Location_Marc'}) && length($item->{'Location_Marc'}) > 1) {
        #     $mmc->set( 'call_number', $item->{'Location_Marc'} );
        # } else {
            my $field852 = $record->field( '852' );
            if (defined $field852) {
		$mmc->set('call_number', scalar($mmc->get('klassifikationsdel_av_uppställningssignum')));
	    } else {
		$mmc->set('call_number', scalar($mmc->get('beståndsuppgift')));
            }
        # }

=head3 952$p Barcode (mandatory)

From BarCodes.Barcode.

=cut

	$mmc->set('barcode', $item->{'BarCode'}) if $item->{'BarCode'};

	say STDERR "Item without barcode: " . $item->{'IdItem'} unless $item->{'BarCode'};

=head3 952$r Date last seen

"The date that the item was last seen in the library (checked in / checked out
 / inventoried)."

=cut

        if ( defined($item->{'LatestLoanDate'}) && $item->{'LatestLoanDate'} ne '' &&
             defined($item->{'LatestReturnDate'}) && $item->{'LatestReturnDate'} ne '' && dp($item->{'LatestLoanDate'}) > dp($item->{'LatestReturnDate'}) ) {
	    $mmc->set('date_last_seen', fix_date( $item->{'LatestLoanDate'}) );
        } elsif ( defined($item->{'LatestReturnDate'}) && $item->{'LatestReturnDate'} ne '' ) {
            $mmc->set('date_last_seen', fix_date( $item->{'LatestReturnDate'} ));
        } elsif ( defined($item->{'LatestLoanDate'}) && $item->{'LatestLoanDate'} ne '' ) {
            $mmc->set( 'date_last_seen', fix_date( $item->{'LatestLoanDate'} ) );
        }

=head3 952$s Date last checked out

"Last checkout date of item. Display only field."

=cut

        $mmc->set( 'date_last_checkout', fix_date( $item->{'LatestLoanDate'} ) ) if $item->{'LatestLoanDate'};

=head3 952$x     Non-public note

"Internal staff note."

To see what is present in the data:

  SELECT Info, COUNT(*) FROM Items WHERE Info != '' GROUP BY Info;

The Info column seems to contain some weird non-printing char. We work around
this by checking for length greater than 1.

=cut

        if ( defined $item->{'Info'} && length $item->{'Info'} > 1 ) {
	    $mmc->set('internal_staff_note', $item->{'Info'}) if $item->{'Info'} ne ' ';
        }

=head3 952$8 Collection code

Values must be defined in the CCODE authorized values category.

We base this on the Departments table and the value of Items.IdDepartment value.

=cut
	my $iddepartment;
	$iddepartment = defined($item->{IdDepartment}) ? $ccode->{ $item->{'IdDepartment'} } : undef;

	if (defined($iddepartment) && $iddepartment eq 'IGNORE') {
	    $ignoredItem++;
	    next ITEM;
	};

	$includedItem++;

	$mmc->set('collection_code',  $iddepartment ) if defined($iddepartment);


=head3 952$y Itemtype (mandatory)

lib/Itemtype.pm is pulled in and the subroutine C<get_itemtype()> is used to
determin the itemtype of a given record. This subroutine might need editing for
different libraries.

A separate script, called F<itemtypes.pl>, can be used to assess the results
from C<get_itemtype()>. It will ingest the same raw MARCXML data asthe current
script and output the number of occurences for each itemtype, with or without
debug output. Run C<perldoc itemtypes.pl> for more documentation.

=cut
        my $itemtype;
	if ($item->{'IsRemote'}) {
	    $itemtype = 'FJARRLAN';
	}
# elsif (defined($item->{'MaterialType'})) {
#	    $itemtype = $item->{'MaterialType'};
#	}
	else {
	    $itemtype = get_itemtype( $record );
	    $itemtype = refine_itemtype( $mmc, $record, $item, $itemtype );
	}
	if (defined($item->{'MaterialType'}) && $item->{'MaterialType'} ne '') {
	    print("MaterialType: " . $item->{'MaterialType'} . " itemtype: $itemtype\n");
	}
	add_itemtype_stat($itemtype, $item->{'CA_CATALOG_LINK_TYPE_ID'});
	$mmc->set('itemtype', $itemtype);
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
        sub _ap {
            my ($a, $b) = @_;
            if (defined($b)) {
                return "$a $b";
            }
            return $a;
        }

	if (defined($item->{'IdStatusCode'})) {
	    my $status = $item->{'IdStatusCode'};
	    if (defined($notforloan->{$status})) {
		$mmc->set('not_for_loan', $notforloan->{$status});
	    }
	    if (defined($lost->{$status})) {
		$mmc->set('lost_status', $lost->{$status});
	    }
	    if (defined($damaged->{$status})) {
		$mmc->set('damaged_status', $damaged->{$status});
	    }
	}


=head3 952$7 Not for loan



=cut
	if ($item->{'Hidden'}) {
	    #$mmc->set('not_for_loan', 4);
	    warn "Hidden item: " . $item->{IdItem};
	}

	my %loanperiods = (
	    'Normallån' => [],
	    '3-dagars' => [],
	    '7-dagars' => [],
	    '14-dagars' => [],
	    'Sommarlån' => [],
	    'Fjärrlån' => [],
	    'Referens' => [],
	    'Kortlån 7-dagar' => [],
	    'Förskolelån' => [],
	    'Kortlån 14-dagar' => [],
	    'Bokkassar' => ['itemtype' => 'TEMAVUXEN'],

	    #'DVD' => ['itemtype' => 'FILM'],
	    #'tillfälligt korttidslån' => ['itemtype' => 'KORTLON'],
	    #'Fjärrlån. Går att låna hem' => ['not_for_loan' => 3, 'itemtype' => 'FJARRLAN'],
	    #'Fjärrlån.  Ej för hemlån.' => ['not_for_loan' => 3, 'itemtype' => 'FJARRLAN'],
	    #'Korttidslån' => ['itemtype' => 'KORTLAN'],
	    #'Ej hemlån' => ['not_for_loan' => 1],
	    #'Tidskrifter' => ['not_for_loan' => 2, 'itemtype' => 'TIDSKRIFT'],
	    #'Talböcker deponerade' => ['itemtype' => 'DAISY'],
	    #'Stavgång' => ['itemtype' => 'STAVGANG'],
	    #'CD-ROM' => ['itemtype' => 'ELEKRESURS'],
	    #'Film' => ['itemtype' => 'FILM'],
	    #'Långlån' => [],
	    #'Flygelnyckel' => ['itemtype' => 'FLYGELNYCK'],
	    #'Fjärr-kopia' => [],
	    #'depositioner på Språkhyllan' => [],
	    #'Barn tidskrifter' => ['itemtype' => 'BARN TIDSK', 'not_for_loan' => 2],
	    #'Språkdepositioner' => [],
	    #'Korttidslån ny litteratur' => ['itemtype' => 'KORTLAN'],
	    #'Fjärrlån => öppen lånetid', ['not_for_loan' => 3, 'itemtype' => 'FJARRLAN'],
	    #'Daisyspelare' => [],
	    #'Bilaga' => [],
	    #'E-media' => ['itemtype' => 'ELEKRESURS']);
	    );
	if (defined($item->{'LoanPeriodName'}) && exists($loanperiods{$item->{'LoanPeriodName'}})) {
	    my @lp = @{$loanperiods{$item->{'LoanPeriodName'}}};
	    for (my $i = 0; $i < scalar(@lp); $i+=2) {
		$mmc->set($lp[$i], $lp[$i + 1]);
	    }
	}
	
	    
        # Mark the item as done, if we are told to do so
        #if ( $flag_done ) {
	#   $sth_done->execute( $item->{'IdItem'} );
        #}

        $count_items++;

      } # end foreach items

=head2 Add 942

Just add the itemtype in 942$c.

=cut

      if ( !$last_itemtype ) {
	  my $itemtype = get_itemtype( $record );
	  $last_itemtype = refine_itemtype( $mmc, $record, undef, $itemtype );
	  
	  $mmc->set('biblioitemtype', $last_itemtype);
      }

      print IGNORED_BIBLIOS ($record->field('001')->data() . "\n") unless $includedItem || !$ignoredItem;

      if ($opt->xml_output) {
	  $file->write( $record );
      } else {
	  print $file $record->as_usmarc;
      }
      say MARC::File::XML::record( $record ) if $opt->debug;
      say "Record was ignored." if $opt->debug && !($includedItem || !$ignoredItem);

      $item_context->{items} = $mmc->get_items_set_sql;

      $tt2->process( 'items.tt', $item_context, \*ITEM_OUTPUT,  {binmode => ':utf8'} ) || die $tt2->error();      

      $mmc->reset();
      
      # Count and cut off at the limit if one is given
      $count++;
      $progress->update( $count );
      last if $limit && $limit == $count;

    } # end foreach record
    unless ($opt->xml_input) {
	$batch->close();
    }
}

$progress->update( $limit );

say "$count records, $count_items items done";
say "Did you remember to load data into memory?" if $count_items == 0;

for my $itemtype (sort(keys %itemtype_stats)) {
    say "$itemtype\t$itemtype_stats{$itemtype}->{count}";
    for my $ca_link_type_id (sort(keys %{$itemtype_stats{$itemtype}->{extra}})) {
	say "    $ca_link_type_id\t$itemtype_stats{$itemtype}->{extra}->{$ca_link_type_id}->{count}";
    }
}
#for my $cattype (sort(keys %catid_types)) {
#    say "$cattype\t$catid_types{$cattype}->{count}";
#}

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

## Internal subroutines.

sub fix_date {
    my ( $d ) = @_;

    return dp($d)->strftime('%F');
}


sub num_records_ {
    $input_file = shift;
    my $n = 0;
    foreach my $f (glob $input_file) {
	my $batch;
	if ($opt->xml_input) {
	    $batch = MARC::Batch->new('XML', $f);
	} else {
	    $batch = MARC::File::USMARC->in( $f );
	}
	while ($batch->next()) {
	    $n++;
	}
	unless ($opt->xml_input) {
	    $batch->close();
	}
    }
    return $n;
}

sub check_multi_fields {
    my $mmc = shift;
    my $fields = shift;
    my $values = shift;

    my %values = ();

    for my $val (@$values) {
	$values{$val} = 1;
    }

    for my $field (@$fields) {
	for my $v ($mmc->get($field)) {
	    if (defined($v) && defined ($values{$v})) {
		return 1;
	    }
	}
    }
    return 0;
}

sub refine_itemtype {
    my $mmc = shift;
    my $record = shift;
    my $item = shift;
    my $original_itemtype = shift;

    my $itemtype = $original_itemtype;

    my $ccall = $item->{'Location_Marc'};
    my $localshelf;
    if (defined($item)) {
	$localshelf = defined($item->{'IdLocalShelf'}) ? $loc->{ $item->{'IdLocalShelf'} } : (defined($item->{'LocalShelf'}) ? $item->{'LocalShelf'} : undef);
    }

    my $classificationcode = $mmc->get('klassifikationskod');
    my $ccode = $mmc->get('collection_code');

    my $checkccall = sub {
	my $re = shift;
	return defined($ccall)              &&              $ccall =~ /$re/i ||
               defined($classificationcode) && $classificationcode =~ /$re/i;
    };

    # Alla böcker med Hyllplats ”Storstil” ska även till exemplarkategori ”Storstil”
    # 555 resultat hittade för 'location,wrdl: *storstil*' med begränsningar: 'mc-itype,phr:BOK TIDA' i Bibliotek Mellansjö katalog.
    # 
    #
    if ($original_itemtype eq 'BOK' && defined($localshelf) && $localshelf =~ /Storstil/i) {
	return 'STORSTIL';
    }
    # 
    # Allt under lokal placering ”Cd-hylla” ska vara exemplartyp ”Musik CD”
    #
    if (defined($localshelf) && $localshelf =~ /Cd-hylla/i) {
	return 'MUSIKCD'
    }
    #  
    # 92 resultat hittade för 'callnum,wrdl: hcf/o or callnum,wrdl: hcg/o or callnum,wrdl: uhc/o or callnum,wrdl: uhce/o' med begränsningar: 'TIDA' i Bibliotek Mellansjö katalog.
    # 
    # Media med klassifikation Hcf/o, hcg/o, uHc/o ska till kategorin ”Blandad resurs bok och cd barn”

    if ($checkccall->('((hc[fg])|(uhce?))\/o')) {
	return 'BCDBOK';
    }
    # 
    # 59 resultat hittade för 'callnum,wrdl: hce/o or callnum,wrdl: hc/o' med begränsningar: 'TIDA' i Bibliotek Mellansjö katalog.
    # 
    # Media med klassifikation hc/o och hce/o ska till kategorin ”blandad resurs bok och cd”

    if ($checkccall->('hce?\/o')) {
	return 'CDBOK';
    }

    # 
    #  
    # 7 resultat hittade  med begränsningar: 'mc-itype,phr:TIDSKRIFT mc-ccode:'Barn' or mc-ccode:'BoU' or mc-ccode:'Ungdom' TIDA' i Bibliotek Mellansjö katalog.
    # 
    # Barn tidskrift verkar Tidaholm ha 7st. De ligger under vanliga tidskrifter och ska till ”barn tidskrift”.
    #

    if ($original_itemtype eq 'TIDSKRIFT' && defined($ccode) && $ccode =~ /^((Barn)|(Ungdom)|(BoU$))/i) {
	return 'BTIDSK';
    }
    
    #  
    # 164 resultat hittade  med begränsningar: 'mc-itype,phr:DAISY mc-ccode:'Barn' or mc-ccode:'BoU' or mc-ccode:'Ungdom' TIDA' i Bibliotek Mellansjö katalog.
    # 
    # 164 talböcker som ska till ”barn talbok”
    #

    if (($original_itemtype eq 'TALBOK' || defined($localshelf) && $localshelf =~ /talbok/i ) && defined($ccode) && $ccode =~ /^((Barn)|(Ungdom)|(BoU$))/i) {
	return 'BTALBOK';
    }
    
    #  
    # 208 resultat hittade för 'callnum,wrdl: hcf/cd or callnum,wrdl: hcf/lc' med begränsningar: 'TIDA' i Bibliotek Mellansjö katalog.
    # 
    # Dessa 208 ska tillhöra kategori ”barn ljudbok cd”
    # 
    #  
    # 140 resultat hittade för 'callnum,wrdl: hcg/cd or callnum,wrdl: hcg/lc' med begränsningar: 'TIDA' i Bibliotek Mellansjö katalog.
    # 
    # Dessa 140 ska tillhöra kategori ”barn ljudbok cd”
    # 
    #  
    # 32 resultat hittade för 'callnum,wrdl: uhc/cd or callnum,wrdl: uhc/lc' med begränsningar: 'TIDA' i Bibliotek Mellansjö katalog.
    # 
    # Dessa 32 ska tillhöra kategori ”barn ljudbok cd”
    # 
    #  
    # 35 resultat hittade för 'callnum,wrdl: uhce/cd or callnum,wrdl: uhce/lc' med begränsningar: 'TIDA' i Bibliotek Mellansjö katalog.
    # 
    # Dessa 35 ska tillhöra kategori ”barn ljudbok cd”
    #

    if ($checkccall->('((hc[fg])|(uhce?))\/cd')) {
	return 'BCDBOK';
    }
    
    #  
    # 8 resultat hittade  med begränsningar: 'mc-itype,phr:MP3 mc-ccode:'Barn' or mc-ccode:'BoU' or mc-ccode:'Ungdom' TIDA' i Bibliotek Mellansjö katalog.
    # 
    # 8 ljudbok mp3 som ska till ”ljudbok mp3 barn”
    #

    if (($original_itemtype eq 'MP3' || defined($localshelf) && $localshelf =~ /mp3/i ) && defined($ccode) && $ccode =~ /^((Barn)|(Ungdom)|(BoU$))/i) {
	return 'BMP3';
    }

    if (($original_itemtype eq 'FILM' && defined($ccode)  && $ccode =~ /^((Barn)|(Ungdom)|(BoU$))/i)) {
	return 'BFILM';
    }

    if (($original_itemtype eq 'NOTER' && defined($ccode)  && $ccode =~ /^((Barn)|(Ungdom)|(BoU$))/i)) {
	return 'BNOTER';
    }
    
    #  
    # 10289 resultat hittade  med begränsningar: 'mc-itype,phr:BOK mc-ccode:'Barn' or mc-ccode:'BoU' or mc-ccode:'Ungdom' TIDA' i Bibliotek Mellansjö katalog.
    # 
    # 10289 barnböcker under kategorin ”bok” som ska till kategori ”barnbok”

    if ($original_itemtype eq 'BOK' && defined($ccode) && $ccode =~ /^((Barn)|(Ungdom)|(BoU$))/i) {
	return 'BBOK';
    }

    if ($original_itemtype eq 'TEMAVUXEN' && defined($ccode) && $ccode =~ /^((Barn)|(Ungdom)|(BoU$))/i) {
	return 'TEMABARN';
    }
 

    my  $children = (defined($ccall) && $ccall =~ /hc(f|g|(,u))/i) or (defined $classificationcode && $classificationcode =~ /,u/);

    if ($original_itemtype eq 'LJUDBOK') {
	if (defined($ccall) && $ccall =~ /mp3/i) {
	    $itemtype = $children ? 'BMP3' : 'MP3';
	} elsif ($children) {
	    $itemtype = 'BCDBOK';
	} else {
	    $itemtype = 'CDBOK'
	}
    } elsif ($original_itemtype eq 'TIDSKRIFT') {
	$children = $children || check_multi_fields($mmc, ['okontrollerad_term',  'genre_form_uppgift_eller_fokusterm'],
						   ['Barn', 'Ungdom', 'Barn och ungdom']);
	if ($children) {
	    $itemtype = 'BTIDSKRIFT';
	}
    } elsif ($original_itemtype eq 'BOK') {
	$children = $children || check_multi_fields($mmc, ['okontrollerad_term',  'genre_form_uppgift_eller_fokusterm'],
				    ['Barnbok', 'Barnböcker', 'Ungdomsbok', 'Ungdomsböcker',
				     'Barn och ungdom', 'Barn och ungdsomsbok', 'Barn och ungdomsböcker']);
	if ($children) {
	    $itemtype = 'BBOK';
	}
    }


    
    return $itemtype;
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
