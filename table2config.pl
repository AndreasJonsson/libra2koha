#!/usr/bin/env perl

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

my ($opt, $usage) = describe_options(
    '%c %o <some-arg>',
    [ 'dir=s', "table directory", { required => 1  } ],
    [ 'name=s', 'table name', { required => 1 } ],
    [ 'columndelimiter=s', 'column delimiter',  { default => '!*!' } ],
    [ 'rowdelimiter=s',  'row delimiter'      ],
    [ 'encoding=s',  'character encoding',      { default => 'utf-16' } ],
    [ 'timezone=s',  'time zone' ],
    [ 'quote=s',  'quote character' ],
    [ 'headerrows=i', 'number of header rows',  { default => 0 } ],
    [ 'key=i', 'index of key column', { required => 1} ],
    [ 'value=i', 'index of value column' ],
    [ 'comment=i@', 'index of columns to include as comments' ],
    [],
    [ 'verbose|v',  "print extra stuff"            ],
    [ 'help',       "print usage message and exit", { shortcircuit => 1 } ],
    );

print $usage->text if ($opt->help);

my $filename = $opt->dir . '/' . $opt->name;
my $fh;

my $found_file = 0;
foreach my $suffix ('', '.txt', '.csv') {
    if (open ($fh, "<:encoding(" . $opt->encoding . "):crlf", ($filename  . $suffix))) {
	$found_file = 1;
	last;
    }
}
die ("Didn't find any table file for " . $opt->name) unless ($found_file);

my $dt;
if ($opt->timezone) {
    $dt = DateTime->now( time_zone => $opt->timezone );
} else {
    $dt = DateTime->now();
}

say "---";
say "# Generated from $filename";
say "# " . $dt->ymd . ' ' . $dt->hms;
say ''  ;

my $csv = Text::CSV->new({
    quote_char => $opt->quote,
    sep_char => $opt->columndelimiter,
    eol => $opt->rowdelimiter });

for (my $i = 0; $i < $opt->headerrows; $i++) {
    die "Filehandle is closed! $i" unless defined(fileno($fh));
    my $row = $csv->getline( $fh );
}

while (my $row = $csv->getline( $fh ) ) {
    my $key     = $row->[ $opt->key ];
    my $value   = '';
    if (defined($opt->value)) {
	$value = $row->[$opt->value];
    }
    my @comments = map { $row->[$_] } @{$opt->comment};

    my $comment = join(", ", @comments);
    say "$key: '$value' # $comment";

}

close $fh;
