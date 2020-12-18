#!/usr/bin/perl

# Copyright 2015 Magnus Enger Libriotech
# Copyright 2017 Andreas Jonsson andreas.jonsson@kreablo.se

=head1 NAME

table2config.pl - Helper script for turning a table into a YAML config file.

=head1 SYNOPSIS

  perl table2config.pl /path/to/tablename.txt 0 2

=head1 DESCRIPTION

Arguments:

=over 4

=item * --dir Data directory with table files

=item * --name A name of a table file.  If file is not found, suffixes .txt and .csv will be tried.

=item * --key The index of the column that should be turned into the key

=item * --comment The indicies of the columns that should be turned into a comment (0 or more)

=item * --value The index of the value column (optional).

=back

Se --help for further options.

So with this file as the starting point ("!*!" is the field separator):

  1!*!01!*!Barn!*!^@!*!^@!*!-1!*!^@!*!20071121!*!12:53:37!*!libra!*!20091105!*!14:02:02!*!kran
  2!*!02!*!Vuxen!*!^@!*!^@!*!0!*!^@!*!20071121!*!12:53:37!*!libra!*!!*!!*!
  3!*!08!*!Referens!*!^@!*!^@!*!0!*!^@!*!20071121!*!12:53:37!*!libra!*!!*!!*!
  4!*!eHub!*!E-lån!*!E-lån!*!E-lån!*!0!*!^@!*!20140109!*!13:35:51!*!libra!*!!*!!*!

and this invocation of the script:

  table2config.pl --dir=/path/to --name=Departments --key=0 --comment=2 > ccode.yaml

the outout will look like this:

  ---
  # Generated from /home/magnus/Nedlastinger/molndal/Koha/Departments.txt
  # 2015-09-21 08:14:38
  1: '' # Barn
  2: '' # Vuxen
  3: '' # Referens
  4: '' # E-lån

The empty values will now have to be filled in by hand, before F<ccode.yaml> can
be used as a config file by F<records.pl>

=cut

use DateTime;
use Modern::Perl;
use Text::CSV;
use Getopt::Long::Descriptive;
use Data::Dumper;
use TupleColumn;
use YAML::Syck qw( Dump LoadFile );
use DBI;

binmode STDOUT, ":utf8";
$YAML::Syck::ImplicitUnicode = 1;

my ($opt, $usage) = describe_options(
    '%c %o <some-arg>',
    [ 'dir=s', "table directory", { required => 1  } ],
    [ 'config=s', 'config directory', { required => 1 } ],
    [ 'name=s', 'table name' ],
    [ 'query=s', 'sql query' ],
    [ 'format=s', 'output format (yaml or csv)', { default => 'yaml' } ],
    [ 'columndelimiter=s', 'column delimiter',  { default => ',' } ],
    [ 'rowdelimiter=s',  'row delimiter'      ],
    [ 'escape=s', 'escape character', { default => "\\" } ],
    [ 'encoding=s',  'character encoding',      { default => 'utf-16' } ],
    [ 'specencoding=s',  'character encoding of specfile',      { default => 'utf-8' } ],
    [ 'ext=s',     'table filename extension', { default => '.txt' } ],
    [ 'timezone=s',  'time zone' ],
    [ 'quote=s',  'quote character', { default => '"' } ],
    [ 'headerrows=i', 'number of header rows',  { default => 0 } ],
    [ 'key=s', 'index of key column (integer or tuple of integers)', { required => 1} ],
    [ 'stringkey', 'Is key a string.' ],
    [ 'value=i', 'index of value column' ],
    [ 'filtercol=i', 'filter on column string equality (requires filterval)', { default => undef } ],
    [ 'filterval=s', 'filter on column string equality (requires filtercol)', { default => undef } ],
    [ 'comment=i@', 'index of columns to include as comments', { default => [] }],
    [],
    [ 'verbose|v',  "print extra stuff"            ],
    [ 'help',       "print usage message and exit", { shortcircuit => 1 } ],
    );

if ($opt->help || !valid($opt)) {
    print STDERR $usage->text;
    exit 0;
}

my $config;
if ( -f $opt->config . '/config.yaml' ) {
    print STDERR "Loading config.yaml\n" if $opt->verbose;
    $config = LoadFile( $opt->config . '/config.yaml' );
}

if (!defined $opt->name && !defined $opt->query) {
    die "Either --name or --query must be specified.";
}

if (defined $opt->name && defined $opt->query) {
    die "Exactly one of --name or --query must be specified.";
}

sub valid {
    my $opt = shift;

    unless ($opt->key =~ /^\d+$/ or parse_tuple($opt->key)) {
	return 0;
    }

    return 1;
}

my $dt;
if ($opt->timezone) {
    $dt = DateTime->now( time_zone => $opt->timezone );
} else {
    $dt = DateTime->now();
}

my $rowdelim = $opt->rowdelimiter;
#$rowdelim =~ s/\n/\\n/g;
#$rowdelim =~ s/\r/\\r/g;


sub intkey {
    return sub {
	my $row = shift;

	return $row->[ $opt->key ];
    };
}

sub tuplekey {
    my $tuple = shift;
    return sub {
	my $row = shift;
	return encode_tuple(extract_tuple($row, $tuple));
    };
}

my $keyextract;
my $keyuniq;
my %keys = ();
$keyuniq = sub {
    my $k = shift;
    if (defined $keys{$k}) {
	return 0;
    }
    $keys{$k} = 1;
    return 1;
};

if ($opt->key =~ /^\d+$/) {
    $keyextract = intkey();
} else {
    $keyextract = tuplekey(parse_tuple($opt->key));
}

my %config = ();

$YAML::Syck::Headless = 1;
$YAML::Syck::SingleQuote = 1;
$YAML::Syck::ImplicitUnicode = 1;

my $get_row;

if  (defined $opt->query) {
    my $dbh = DBI->connect( $config->{'db_dsn'}, $config->{'db_user'}, $config->{'db_pass'}, { RaiseError => 1, AutoCommit => 1 } );
    my $sth = $dbh->prepare( $opt->query );
    $sth->execute() or die "Failed to execute query.";
    say "---";
    say "# Generated from query " . $opt->query;
    say "# " . $dt->ymd . ' ' . $dt->hms;
    say ''  ;

    $get_row = sub {
	$sth->fetchrow_arrayref;
    }
} else {
    my $filename = $opt->dir . '/' . $opt->name . $opt->ext;
    my $fh;

    my $found_file = 0;
    if (open ($fh, "<:encoding(" . $opt->encoding . ")", $filename)) {
	$found_file = 1;
    }
    die ("Didn't find any table file for " . $opt->name) unless ($found_file);

    my $csv = Text::CSV->new({
	binary => 1,
	quote_char => $opt->quote,
	sep_char => $opt->columndelimiter,
	eol => $rowdelim,
	escape_char => $opt->escape
    });

    say STDERR $csv->error_diag if $csv->error_diag;

    say "---";
    say "# Generated from $filename";
    say "# " . $dt->ymd . ' ' . $dt->hms;
    say ''  ;

    for (my $i = 0; $i < $opt->headerrows; $i++) {
	die "Filehandle is closed! $i" unless defined(fileno($fh));
	my $row = $csv->getline( $fh );
    }

    $get_row = sub {
	return $csv->getline( $fh ) 
    }

}

while (my $row = $get_row->()) {

    my $key     = $keyextract->($row);

    utf8::upgrade($key);

    next unless $keyuniq->($key);

    my $value   = '';
    if (defined($opt->value)) {
	$value = $row->[$opt->value];
    }

    utf8::upgrade($value);

    if (defined($opt->filterval) && defined($opt->filtercol)) {
	my $filterval = $row->[$opt->filtercol];
	my $filtercol = $opt->filtercol;
	my $optval = $opt->filterval;
	next if ($filterval ne $opt->filterval);
    }
    my @comments = map { $row->[$_] } @{$opt->comment};

    my $comment = join(", ", @comments);
    if ($opt->stringkey) {
	$key =~ s/["\\]/\\$&/g;
	$key = '"' . $key . '"';
    }
    my $line = Dump({ $key => $value });
    chomp $line;
    say $line, " # $comment";
}

