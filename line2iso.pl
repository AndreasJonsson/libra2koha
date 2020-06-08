#!/usr/bin/perl

# line2iso.pl
# Copyright 2009 Magnus Enger

# This is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This file is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this file; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

use MARC::File::USMARC;
use MARC::File::XML ( BinaryEncoding => 'utf8', RecordFormat => 'NORMARC' );
use MARC::Record;
use Getopt::Long::Descriptive;
use Modern::Perl;
use DelimExportCat;
use Scalar::Util qw(blessed);
use utf8;

my ($opt, $usage) = describe_options(
    '%c %o <some-arg>',
    [ 'acc', "Accumulate records" ],
    [ 'limit=i', 'Limit the number of records to output.' ],
    [ 'xml', 'Produce marc-xml output.' ],
    [ 'dir=s', "table directory", { required => 1  } ],
    [ 'table=s', 'table name', { required => 1 } ],
    [ 'format=s', 'Source format', { default => 'libra' } ],
    [ 'ext=s',     'table filename extension', { default => '.txt' } ],
    [ 'columndelimiter=s', 'column delimiter',  { default => '!*!' } ],
    [ 'rowdelimiter=s',  'row delimiter'      ],
    [ 'encoding=s',  'character encoding',      { default => 'utf-8' } ],
    [ 'output=s', 'file name of output' ],
    [ 'quote=s',  'quote character' ],
    [ 'item-procs=s', 'item processors' ],
    [ 'bom', 'use bom', { default => 0 } ],
    [ 'escape=s', 'escape character', { default => undef } ],
    [ 'headerrows=i', 'number of header rows',  { default => 0 } ],
    [ 'delimited', 'use DelimExportCat class',  { default => 1 } ],
           [],
           [ 'verbose|v',  "print extra stuff"            ],
           [ 'debug|d',    "print debug stuff"            ],
           [ 'help',       "print usage message and exit", { shortcircuit => 1 } ],
         );

print $usage->text if ($opt->help);

if (!defined $opt->output) {
    if ($opt->xml) {
	binmode STDOUT, ":encoding(utf-8)";
    } else {
	binmode STDOUT;
    }
} else {
    binmode STDOUT, ":utf8";
}

sub trim {
   my $x = shift;
   $x =~ s/^\s+//;
   $x =~ s/\s+$//;
   return $x;
}

my $filename = $opt->dir . '/' . $opt->table . $opt->ext;

say STDERR "filename: $filename";

# Check that the file exists
if (!-e $filename) {
  print "The file " . $filename . " does not exist...\n";
  exit;
}

my $fh;
if ($opt->bom) {
    use File::BOM;
    open($fh, "<:encoding(" . $opt->encoding . "):via(File::BOM)", $filename) or die "Couldn't open \"" . $filename . "\": $!";
} else {
    open($fh, "<:encoding(" . $opt->encoding . ")", $filename) or die "Couldn't open \"" . $filename . "\": $!";
}

my $output_fh;
if (defined $opt->output) {
    open $output_fh, ">", $opt->output;
    binmode $output_fh;
    if ($opt->xml) {
	binmode $output_fh, ":encoding(utf-8)";
    } else {
	binmode $output_fh, ":utf8";
    }
} else {
    $output_fh = \*STDOUT;
}

if ( $opt->xml ) {
    say $output_fh MARC::File::XML::header();
}

sub match_series_ {
    my $record = shift;
    my $seriesre = shift;
    my $tag = shift;
    my $sf = shift;

    my $f = $record->subfield($tag, $sf);

    return (defined $f && $f =~ /$seriesre/i);
}

sub match_series {
    my $s = shift;
    my $sre = shift;
    return  match_series_($s, $sre, '490', 'a') ||
	match_series_($s, $sre, '440', 'a');
}

sub has_items {
    my $record = shift;
    return defined scalar($record->field('952'));
}

my %obsolete_callnumbers = (
    '001 Bibliografier' => 1,
    '001.2 Förteckningar över offentligt tryck' => 1,
    '001.7 Bibliotekskataloger' => 1,
    '003 Periodikaförteckningar' => 1,
    '004 ' => 1,
    '010 Uppslagsböcker' => 1,
    '010 Uppslagsböcker REF' => 1,
    '010.1 Kartor' => 1,
    '010.1 Kartor REF' => 1,
    '011 Matriklar och kalendrar' => 1,
    '011 Matriklar och kalendrar REF' => 1,
    '012 Ordböcker och lexika' => 1,
    '012 Ordböcker och lexika REF' => 1,
    '013 Språk‑ och skrivanvisningar' => 1,
    '013 Språk‑ och skrivanvisningar REF' => 1,
    '020.1 Författningssamlingar' => 1,
    '027 Historia' => 1,
    '028 Filosofi' => 1,
    '04 Forskning och undervisning' => 1,
    '04 Forskning och undervisning REF' => 1,
    '060 Riksdagstryck' => 1,
    '060 Riksdagstryck REF' => 1,
    '061 Finansväsen och förvaltning' => 1,
    '061.1 Statsliggaren' => 1,
    '061.2 Regeringens budgetförslag' => 1,
    '062 Statistik' => 1,
    '062.1 SOS' => 1,
    '062.2 Övrig statistik' => 1,
    '062.2 Övrig statistik REF' => 1,
    '063.1 Ds ' => 1,
    '063.2 SOU ' => 1,
    '070 Tidskrifter' => 1,
    '070 Tidskrifter MAG' => 1,
    '072 Verksamhetsberättelser, anslagsframställningar   ' => 1,
    '10 Tekniska handböcker' => 1,
    '10 Tekniska handböcker REF' => 1,
    '10.1 Teknik' => 1,
    '11 Fysik Kemi Matematik Datateknik' => 1,
    '11 Fysik Kemi Matematik Datateknik REF' => 1,
    '111 Fysik' => 1,
    '112 Kemi' => 1,
    '112 Kemi REF' => 1,
    '113 Matematik. Statistiska metoder' => 1,
    '13 Biologi' => 1,
    '131 Botanik' => 1,
    '131 Botanik REF' => 1,
    '132 Zoologi' => 1,
    '132 Zoologi REF' => 1,
    '133 Ekologi' => 1,
    '133 Ekologi REF' => 1,
    '134 Mikrobiologi' => 1,
    '135 Genetik' => 1,
    '14 Limnologi. Oceanografi' => 1,
    '15 Medicin' => 1,
    '20 Allmän miljövård' => 1,
    '20 Allmän miljövård REF' => 1,
    '21 Energi' => 1,
    '22 Fysisk planering' => 1,
    '23 Framtidsfrågor' => 1,
    '25 Miljöledning' => 1,
    '3 Naturresurser' => 1,
    '301 Naturresursplanering' => 1,
    '31 Naturvård' => 1,
    '311 Inventeringar och skötselplaner' => 1,
    '312 Naturvårdsobjekt: Beskrivningar och föreskrifter' => 1,
    '312 Naturvårdsobjekt: Beskrivningar och föreskrifter REF' => 1,
    '313 Skyddsvärda landskapstyper' => 1,
    '313 Skyddsvärda landskapstyper REF' => 1,
    '32 Natur och landskapsbild' => 1,
    '33 Idrott, friluftsliv och turism' => 1,
    '33 Idrott, friluftsliv och turism REF' => 1,
    '4 Renhållning och avfall' => 1,
    '41 Renhållning' => 1,
    '42 Avfallstyper: Mängd och behandling' => 1,
    '42 Avfallstyper: Mängd och behandling REF' => 1,
    '43 Återvinning' => 1,
    '44 Avfallet och avfallsbehandlingens miljöeffekter' => 1,
    '5 Luftvård' => 1,
    '5 Luftvård REF' => 1,
    '51 Luftvårdsplanering. Övervakning och kontroll' => 1,
    '52 Mät‑ och analysmetoder' => 1,
    '53 Spridning, transport och deposition av föroreningar' => 1,
    '54 Utsläpp och reningsmetoder' => 1,
    '55 Luftföroreningsundersökningar' => 1,
    '59 Buller' => 1,
    '6 Vattenvård' => 1,
    '6 Vattenvård REF' => 1,
    '61 Vattenföroreningar' => 1,
    '61 Vattenföroreningar REF' => 1,
    '63 VA‑teknik och kommunalavlopp' => 1,
    '66 Översiktlig vattenvårdsplanering' => 1,
    '67 Försurning. Eutrofiering. Sjörestaurering' => 1,
    '69 Vattenundersökningar' => 1,
    '7 Miljögifter ‑ Toxikologi' => 1,
    '7 Miljögifter ‑ Toxikologi REF' => 1,
    '712 Miljöeffekter' => 1,
    '719 Transport av hälso‑ och miljöfarliga ämnen' => 1,
    '719 Transport av hälso‑ och miljöfarliga ämnen REF' => 1,
    '72 Grundämnen och oorganiska föreningar' => 1,
    '721 Metaller' => 1,
    '723 Kväve‑ och fosforföreningar' => 1,
    '729 Övriga grundämnen och oorganiska föreningar' => 1,
    '73 Organiska föreningar' => 1,
    '73 Organiska föreningar REF' => 1,
    '74 Speciella produkter' => 1,
    '741 Bekämpningsmedel' => 1,
    '741.1 Herbicider' => 1,
    '741.3 Insekticider' => 1,
    '742 Lösningsmedel och drivmedel' => 1,
    '749 Övriga produkter' => 1,
    '78 Radioaktiva ämnen samt elektromagnetisk strålning' => 1,
    '81 Jordbruk' => 1,
    '82 Husdjursskötsel inkl renar' => 1,
    '83 Skogsbruk' => 1,
    '84 Fiske. Vattenbruk' => 1,
    'Video' => 1,
    '1.2 Löpnummersviter' => 1,
    'Arkiv' => 1,
    'NC Rapporter' => 1,
    'MAG  ' => 1,
    '2.1 Magasinerat fackhylleböcker' => 1,
    '020.1 Lagsamlingar och författningssamlingar MAG' => 1,
    '062.2 Övrig statistik MAG' => 1,
    '114 Datateknik MAG' => 1,
    '112 Kemi MAG' => 1,
    '13 Biologi MAG' => 1,
    '131 Botanik MAG' => 1,
    '132 Zoologi MAG' => 1,
    '14 Limnologi. Oceanografi MAG' => 1,
    '15 Medicin MAG' => 1,
    '20 Allmän miljövård MAG' => 1,
    '21 Energi MAG' => 1,
    '22 Fysisk planering MAG' => 1,
    '23 Framtidsfrågor MAG' => 1,
    '241.4 Nederländerna MAG' => 1,
    '3 Naturresurser MAG' => 1,
    '31 Naturvård MAG' => 1,
    '311 Inventeringar och skötselplaner <K> MAG' => 1,
    '311 Inventeringar och skötselplaner MAG' => 1,
    '312 Naturvårdsobjekt: Beskrivningar och föreskrifter MAG' => 1,
    '313 Skyddsvärda landskapstyper MAG' => 1,
    '32 Natur och landskapsbild <K> MAG' => 1,
    '32 Natur och landskapsbild MAG' => 1,
    '33 Idrott, friluftsliv och turism MAG' => 1,
    '4 Renhållning och avfall MAG' => 1,
    '41 Renhållning MAG' => 1,
    '42 Avfallstyper: Mängd och behandling MAG' => 1,
    '43 Återvinning MAG' => 1,
    '44 Avfallet och avfallsbehandlingens miljöeffekter MAG' => 1,
    '5 Luftvård MAG' => 1,
    '51 Luftvårdsplanering. Övervakning och kontroll MAG' => 1,
    '52 Mät‑ och analysmetoder MAG' => 1,
    '54 Utsläpp och reningsmetoder MAG' => 1,
    '55 Luftföroreningsundersökningar MAG' => 1,
    '59 Buller MAG' => 1,
    '6 Vattenvård MAG' => 1,
    '61 Vattenföroreningar MAG' => 1,
    '63 VA‑teknik och kommunalavlopp MAG' => 1,
    '66 Översiktlig vattenvårdsplanering MAG' => 1,
    '67 Försurning. Eutrofiering. Sjörestaurering MAG' => 1,
    '69 Vattenundersökningar MAG' => 1,
    '7 Miljögifter ‑ Toxikologi MAG' => 1,
    '710 Handböcker. Metodik. Skyddsblad MAG' => 1,
    '711 Toxiska effekter MAG' => 1,
    '721 Metaller MAG' => 1,
    '73 Organiska föreningar MAG' => 1,
    '741 Bekämpningsmedel MAG' => 1,
    '741.1 Herbicider MAG' => 1,
    '741.3 Insekticider MAG' => 1,
    '81 Jordbruk MAG' => 1,
    '82 Husdjursskötsel inkl renar MAG' => 1,
    '83 Skogsbruk MAG' => 1,
    '84 Fiske. Vattenbruk MAG' => 1,
    '24 Miljövård i utlandet' => 1,
    '240.0 Norden' => 1,
    '240.1 Finland' => 1,
    '240.2 Island' => 1,
    '240.3 Norge' => 1,
    '240.4 Danmark' => 1,
    '240/242 Europa' => 1,
    '241.0 Belgien' => 1,
    '241.1 Frankrike. Monaco' => 1,
    '241.2 Italien' => 1,
    '241.3 Lichtenstein. Luxemburg' => 1,
    '241.4 Nederländerna' => 1,
    '241.5 Portugal. Spanien' => 1,
    '241.6 Schweiz' => 1,
    '241.7 Storbritannien. Irland' => 1,
    '241.8 Västtyskland' => 1,
    '241.9 Österrike' => 1,
    '242.10 Estland' => 1,
    '242.30 Lettland' => 1,
    '242.31 Litauen' => 1,
    '242.4 Polen' => 1,
    '242.6 Ryssland' => 1,
    '242.7 Tjeckoslovakien' => 1,
    '242.8 Ungern' => 1,
    '243.0 USA' => 1,
    '243.1 Kanada' => 1,
    '245 Sydamerika' => 1,
    '246 Afrika' => 1,
    '247 Asien' => 1,
    '247.1 Japan' => 1,
    '247.2 Kina' => 1,
    '247.3 Indien' => 1,
    '247.4 Israel' => 1,
    '248 Australien med Oceanien' => 1,
    '249 Polarområden' => 1,
    'AB Stockholms län' => 1,
    'C Uppsala län' => 1,
    'D Södermanlands län' => 1,
    'E Östergötlands län' => 1,
    'F Jönköpings län' => 1,
    'G Kronobergs län' => 1,
    'H Kalmar län' => 1,
    'I Gotlands län' => 1,
    'K Blekinge län' => 1,
    'L Kristianstads län' => 1,
    'M Malmöhus län (t.o.m. 1996)' => 1,
    'M.98 Skåne län' => 1,
    'N Hallands län' => 1,
    'O Göteborgs och Bohus län (t.o.m. 1997)' => 1,
    'O Västra Götalands län' => 1,
    'P Älvsborgs län ' => 1,
    'R Skaraborgs län ' => 1,
    'R Skaraborgs län (t.o.m 1997)' => 1,
    'S Värmlands län ' => 1,
    'T Örebro län ' => 1,
    'U Västmanlands län' => 1,
    'W Kopparbergs län' => 1,
    'W Dalarnas län' => 1,
    'X Gävleborgs län' => 1,
    'Y Västernorrlands län' => 1,
    'Z Jämtlands län' => 1,
    'AC Västerbottens län' => 1,
    'BD Norrbottens län' => 1,
    'MIKROFICHE' => 1,
    'INFO' => 1,
    'EXP' => 1,
    'KAT' => 1
    );

sub all_lsnv_items {
    my $record = shift;

    for my $field ($record->field('952')) {
	for my $sf ($field->subfield('p')) {
	    unless ($sf =~ /^LSNV/) {
		return 0;
	    }
	}
    }
    return 1;
}

sub is_nv_record {
    my $record = shift;

    for my $field ($record->field('260')) {
	for my $sf ($field->subfield('b')) {
	    if (grep {lc $_ eq lc(trim($sf))} ('Statens naturvårdsverk', 'Naturvårdsverket', 'SNV', 'SEPA', 'Swedish Environmental Protection Agency')) {
		return 1;
	    }
	}
    }
    return 0;
}

sub is_huvudpost {
    my $record = shift;

    my $ldr = $record->leader;

    if (substr($ldr, 7, 1) ne 's') {
	return 0;
    }

    my $match = 0;
    F260: for my $field ($record->field('260')) {
	for my $sf ($field->subfield('c')) {
	    if ($sf =~ /-/) {
		$match = 1;
		last F260;
	    }
	}
    }

    return 0 unless $match;

    $match = 0;

    F300: for my $field ($record->field('300')) {
	for my $sf ($field->subfield('a')) {
	    if ($sf =~ /s(?:idor)?/) {
		$match = 1;
		last F300;
	    }
	    unless ($sf =~ /\d+(?:-(?:\d+|\.)?)?/) {
		$match = 1;
		last F300;
	    }
	}
    }

    return 0 if $match;

    $match = 0;
    F022: for my $field ($record->field('022')) {
	for my $sf ($field->subfield('a')) {
	    if ($sf =~ /^\d{4}-\d{3}(\d|X)$/) {
		$match = 1;
		last F022;
	    }
	}
    }


    return 0 unless $match;

    $match = 0;
    F222: for my $field ($record->field('222')) {
	for my $sf ($field->subfield('a')) {
	    $match = 1;
	    last F222;
	}
    }

    return 0 unless $match;

    return !has_items($record);
}

sub skip {
    my $record = shift;


    if (match_series($record, qr/^Statens offentliga utredningar/) ||
	match_series($record, qr/^Ds\b/)) {
	return !has_items($record);
    }


    for my $field ($record->field('952')) {
        my $cn   = $field->subfield('o');
	if (defined $cn && $obsolete_callnumbers{$cn} && all_lsnv_items($record)) {
	    return 1;
	}
    }

    if (!is_nv_record($record) && is_huvudpost($record)) {
	return 1;
    }
    
    return 0;
}

sub output {
    my $record = shift;

    if (skip($record)) {
	return;
    }
    
    if ($opt->xml) {
        # print $record->as_xml_record(), "\n";
        say $output_fh MARC::File::XML::record( $record );
    } else {
        print $output_fh  MARC::File::USMARC::encode( $record );
    }
}


if ($opt->delimited) {

    my $dec = DelimExportCat->new( {
        'inputh'             => $fh,
        'limit'              => $opt->limit ? $opt->limit : undef,
        'verbose'            => $opt->verbose,
        'accumulate_records' => $opt->acc,
        'opt'                => $opt,
        'debug'              => $opt->debug
    } );

    while (my $record = $dec->next_record()) {
	if (blessed $record) {
	    foreach my $warning ($record->warnings()) {
		say STDERR "Record " . $record->{record_nr} . " has warnings: " . $warning;
	    }
	    unless ($opt->acc) {
		output($record);
	    }
	}
    }

    if ($opt->format eq 'aleph') {
	$dec->aleph_analyze;
    }

    if ($opt->acc) {
        my %records = %{$dec->get_records()};
        foreach my $record_id (keys %records) {
            my $record = $records{$record_id};
            output($record);
        }
    }

    say STDERR "Num records: " . $dec->record_count if $opt->verbose;

} else {
# Start an empty record
    my $record = MARC::Record->new();

# Counter for records
    my $num = 0;

    my $line_count = 0;
    while (my $line = <$fh>) {

        chomp($line);

        say $line if $opt->debug;

        # For some reason some lines begin with "**"
        # These seem to be errors of some kind, so we skip them
        if ($line =~ /^\*\*/) {
            next;
        }

        # Look for lines that begin with a ^ - these are record delimiters
        if ($line =~ /^\^/) {

            say "\nEND OF RECORD $num" if $opt->verbose;

            # Make sure the encoding is set
            $record->encoding( 'UTF-8' );

            # Check that the record has a 245$a
            if ( $record->field( '245' ) && $record->field( '245' )->subfield( 'a' ) && $record->field( '245' )->subfield( 'a' ) ne '' ) {

                # Output the record in the desired format
                if ($opt->xml) {
                    # print $record->as_xml_record(), "\n";
                    say MARC::File::XML::record( $record );
                } else {
                    print $record->as_usmarc(), "\n";
                }

                # Count the records
                $num++;

                # Check if we should quit here
                if ($opt->limit && $opt->limit == $num) {
                    last;
                }

            }

            # Start over with an empty record
            $record = MARC::Record->new();

            # Process the next line
            next;

        }

        # Some lines are just e.g. "*300 ", we skip these
        if (length($line) < 6) {
            next;
        }

        # Get the 3 first characters, this should be a MARC tag/field
        my $field = substr $line, 1, 3;

        if ($field ne "000" && $field ne "001" && $field ne "003" && $field ne "005" && $field ne "006" && $field ne "007" && $field ne "008") {

            # We have a data field, not a control field

            my $ind1  = substr $line, 4, 1;
            if ($ind1 eq " ") {
                $ind1 = "";
            }
            my $ind2  = substr $line, 5, 1;
            if ($ind2 eq " ") {
                $ind2 = "";
            }

            # Get everyting from character 7 and to EOL
            my $subs  = substr $line, 7;
            if ( $subs ) {

                # Split the string on field delimiters, $
                my @subfields = split(/\$/, $subs);
                my $subfield_count = 0;
                my $newfield = "";

                foreach my $subfield (@subfields) {

                    trim( $subfield );

                    # Skip short subfields
                    if (length($subfield) && length($subfield) < 1) {
                        next;
                    }

                    my $index = substr $subfield, 0, 1;
                    my $value = substr $subfield, 1;

                    if ($subfield_count == 0) {
                        # This is the first subfield, so we create a new field
                        $newfield = MARC::Field->new( $field, $ind1, $ind2, $index => $value );
                    } else {
                        # Subsequent subfields are added to the existing field
                        $newfield->add_subfields( $index, $value );
                    }

                    $subfield_count++;

                }

                $record->append_fields($newfield);

            }

        } else {

            # We have a control field

            my $value = substr $line, 4;
            my $field = MARC::Field->new($field, $value);
            $record->append_fields($field);

        }

        say "Line $line_count" if $opt->verbose;
        $line_count++;

    }

# print "\n$num records processed\n";
}

if ( $opt->xml ) {
    say $output_fh MARC::File::XML::footer();
    print "\n";
}

