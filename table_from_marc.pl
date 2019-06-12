#!/usr/bin/perl -w

use MARC::File::USMARC;
use MARC::File::XML ( BinaryEncoding => 'utf8', RecordFormat => 'MARC21' );
use MARC::Batch;
use DBI;
use Getopt::Long::Descriptive;
use YAML::Syck qw( LoadFile );
use Modern::Perl;
use MarcUtil::MarcMappingCollection;
use TupleColumn;
use CommonMarcMappings;

my ($opt, $usage) = describe_options(
    '%c %o <some-arg>',
    [ 'config=s', 'config directory', { required => 1 } ],
    [ 'infile=s', 'input file', { required => 1 } ],
    [ 'default-branchcode=s', 'Default branchcode', { default => '' } ],
    [ 'outputdir=s', 'output directory', { required => 1 } ],
    [ 'xml-input', 'Expect XML input', { default => 0 }],
    [ 'columns=s@', 'Column mappings (example: (952$p, barcode) )',  { required => 1}],
    [ 'idcolumn=s', 'Identity column mapping', { default => undef } ],
    [ 'tablename=s', 'Name of table', { required => 1 }],
    [],
    [ 'verbose|v',  "print extra stuff"            ],
    [ 'debug',      "Enable debug output" ],
    [ 'help',       "print usage message and exit", { shortcircuit => 1 } ],
);



my $mmc = MarcUtil::MarcMappingCollection::marc_mappings(
    %common_marc_mappings
    );

if ($opt->help) {
    print STDERR $usage->text;
    exit 0;
}

my @column_mappings = map { parse_tuple_string($_) } @{$opt->columns};

my $idcol_mapping;
if (defined $opt->idcolumn) {
    $idcol_mapping = parse_tuple_string($opt->idcolumn);
}

my $config;
if ( -f $opt->config . '/config.yaml' ) {
    print STDERR "Loading config.yaml\n" if $opt->verbose;
    $config = LoadFile( $opt->config . '/config.yaml' );
}

my $dbh = DBI->connect( $config->{'db_dsn'}, $config->{'db_user'}, $config->{'db_pass'}, { RaiseError => 1, AutoCommit => 1 } );



for my $marc_file (glob $opt->infile) {
    my $batch;

    if ($opt->xml_input) {
	$batch = MARC::Batch->new( 'XML', $marc_file );
    } else {
	open FH, "<:raw", $marc_file;
	$batch = MARC::File::USMARC->in( \*FH );
    }

    my $rows = [];

    while (my $record = $batch->next()) {
	$mmc->record($record);

	my %columns = ();

	for my $m (@column_mappings) {
	    my $val = $mmc->get($m->[0]);
	    $columns{$m->[1]} = $val;
	}

	push @$rows, \%columns;
    }

    my @columnnames = ();
    my $idcolname;
    for my $m (@column_mappings) {
	if ($m->[1] eq $idcol_mapping->[1]) {
	    $idcolname = $m->[1];
	} else {
	    push @columnnames, $m->[1];
	}
    }

    for my $row (@$rows) {
	my $first = 1;
	my $sql;
	$sql = defined $idcolname ? "UPDATE `" : "INSERT INTO `";
	$sql .= $opt->tablename . "` SET ";
	for my $c (@columnnames) {
	    if ($first) {
		$first = 0;
	    } else {
		$sql .= ', '
	    }
	    $sql .= '`' . $c . '` = ' . $dbh->quote($row->{$c});
	}
	if (defined $idcolname) {
	    $sql .= ' WHERE `' . $idcolname . '` = ' . $dbh->quote($row->{$idcolname});
	}
	$dbh->do($sql) or die $dbh->errstr;
    }

    unless ($opt->xml_input) {
	$batch->close();
    }
}

sub get_marc_field {
    my $record = shift;
    my $label = shift;

    my ($tag, $subtag) = split '$', $label;

    if (defined($subtag)) {
	return $record->subfield($tag, $subtag);
    } else {
	return $record->controlfield($tag)->data();
    }
};
