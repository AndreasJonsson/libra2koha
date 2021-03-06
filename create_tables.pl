#!/usr/bin/perl

# Copyright 2014 Magnus Enger Libriotech
# Copyright 2017 Andreas Jonsson andreas.jonsson@kreablo.se

=head1 NAME

create_tables.pl - Create database tables.

=head1 SYNOPSIS

 perl create_tables.pl [options] > tables.sql

=head1 DESCRIPTION

This script ingests the *spec.txt files from the Libra export and produces
corresponding "CREATE TABLE" SQL statements, written to STDOUT. 

=cut

use File::Basename;
use Getopt::Long::Descriptive;
use Data::Dumper;
use Template;
use DateTime;
use Pod::Usage;
use Modern::Perl;
use BuildTableInfo;

my %DATE_FORMATS = (
    bookit => '%d-%b-%y',
    libra  => '%Y%m%d',
    #micromarc => '%d.%m.%Y'
    micromarc => '%Y-%m-%d',
    marconly => '%Y-%m-%d',
    sierra => '%Y-%m-%d'
    );

my %DATETIME_FORMATS = (
    bookit => '%d-%b-%y %T',
    libra  => '%Y%m%d %T',
    #micromarc => '%d.%m.%Y %H.%i.%S'
    micromarc => '%Y-%m-%d %H:%i:%S',
    sierra => '%Y-%m-%d %H:%i:%S',
    marconly => '%Y-%m-%d %H:%i:%S'
    );

my %TIME_FORMATS = (
    bookit => '%T',
    libra  => '%T',
    #micromarc => '%H.%i.%S'
    micromarc => '%H:%i:%S',
    sierra => '%H:%i:%S',
    marconly => '%H:%i:%S'
    );

my ($opt, $usage) = describe_options(
    '%c %o <some-arg>',
    [ 'tables=s@', "tables to create", { required => 1  } ],
    [ 'format=s', 'Source format', { default => 'libra' } ],
    [ 'spec=s',    'spec directory',   { required => 1 } ],
    [ 'dir=s',     'tables directory', { required => 1 } ],
    [ 'ext=s',     'table filename extension', { default => '' } ],
    [ 'columndelimiter=s', 'column delimiter',  { default => '!*!' } ],
    [ 'rowdelimiter=s',  'row delimiter'      ],
    [ 'encoding=s',  'character encoding',      { default => 'utf-8' } ],
    [ 'specencoding=s',  'character encoding of specfile',      { default => 'utf-8' } ],
    [ 'quote=s',  'quote character', { default => undef } ],
    [ 'yearoffsethack=i', 'Offset into future dates to guess century of two-digit years.', { default => 1 }],
    [ 'escape=s', 'escape character', { default => undef } ],
    [ 'use-bom', 'Use File::BOM', { default => 0 } ],
    [ 'headerrows=i', 'number of header rows',  { default => 0 } ],
           [],
           [ 'verbose|v',  "print extra stuff"            ],
           [ 'help',       "print usage message and exit", { shortcircuit => 1 } ],
         );

if ($opt->help) {
    print STDERR $usage->text;
    exit 0;
}

print STDERR "Create tables: " . (join ', ',  @{$opt->tables}) . "\n" if $opt->verbose;
print STDERR "Tables: " . $opt->dir . "\n" if $opt->verbose;;
print STDERR "ext: " . $opt->ext . "\n" if $opt->verbose;;
print STDERR "spec: " . $opt->spec . "\n" if $opt->verbose;;
print STDERR "specencoding: " . $opt->specencoding . "\n" if $opt->verbose;;

my  ($csvfiles, $specfiles, $missingcsvs, $missingspecs) =
    build_table_info($opt);

my $DATE_STRTODATE = strtodate($DATE_FORMATS{$opt->format});
my $DATETIME_STRTODATE = strtodate($DATETIME_FORMATS{$opt->format});
my $TIME_STRTODATE = strtodate($TIME_FORMATS{$opt->format});

sub bool_conversion {
    my $s = shift;

    return "IF($s = '', NULL, IF($s REGEXP '^(T(rue)?)|(Y(es))|1\$', TRUE, FALSE))";
}

sub strtodate {
    my $f = shift;

    if ($f =~ /%y/) {
	# Two digit years.  Only support dates up to one year into the future.
	return sub {
	    my $s = shift;
	    return "IF (STR_TO_DATE($s, '" .
		$f ."') > ADDDATE(CURRENT_DATE(), INTERVAL " . $opt->yearoffsethack . " YEAR), ADDDATE(STR_TO_DATE($s, '" .
		$f . "'), INTERVAL -100 YEAR), STR_TO_DATE($s, '" .
		$f . "'))";
	};
    } else {
	return sub {
	    my $s = shift;
	    return "STR_TO_DATE($s, '" . $f . "')";
	};
    }
}

my $ttenc = $opt->encoding;

$ttenc =~ s/-//g;


# Configure Template Toolkit
my $ttconfig = {
    INCLUDE_PATH => '', 
    ENCODING => 'utf8'
};
# create Template object
my $tt2 = Template->new( $ttconfig ) || die Template->error(), "\n";

foreach my $table (@{$opt->tables}) {

    if ($opt->verbose) {
	print STDERR "Creating table $table\n";
    }
    
    die "No spec file for $table" unless defined($specfiles->{$table});
    my $specfile = $opt->spec . '/' . $specfiles->{$table}->{filename};

    my $count = 0;
    my @columns = ();

    my @extra_columns = ();
    for my $c (keys %{$specfiles->{$table}->{columns}}) {
	my $s = $specfiles->{$table}->{columns}->{$c};
	if (defined $s->{typeextra} && $s->{typeextra} =~ /\bautoincrement\b/i) {
	    push @extra_columns, $c;
	}
    }
	
    for my $c (@{$csvfiles->{$table}->{columnlist}}, @extra_columns) {
	my $s = $specfiles->{$table}->{columns}->{$c};
	if (! defined($s->{type})) {
	    die "No type on $table $c: " . Dumper($specfiles->{$table});
	    # print Dumper($specfiles);
	}

	my $key = 0;
	my $unique = 0;
	my $index = 0;
	my $autoincrement = 0;
	
	my $type = $s->{type};
	if (!defined($type)) {
	    $type = '';
	} else {
	    chomp $type;
	}
	my $size;
	if (defined($s->{typeextra}) && $s->{typeextra} ne '') {
	    if ($s->{typeextra} =~ /\bkey\b/i) {
		$s->{typeextra} =~ s/\bkey\b//i;
		$key = 1;
	    }
	    if ($s->{typeextra} =~ /\bunique\b/i) {
		$s->{typeextra} =~ s/\bunique\b//i;
		$unique = 1;
	    }
	    if ($s->{typeextra} =~ /\bindex\b/i) {
		$s->{typeextra} =~ s/\bindex\b//i;
		$index = 1;
	    }
	    if ($s->{typeextra} =~ /\bautoincrement\b/i) {
		$s->{typeextra} =~ s/\bautoincrement\b//i;
		$autoincrement = 1;
	    }
	    $size = $s->{typeextra};
	    chomp $size;
	}
	if ($type eq 'nvarchar') {
	    $type = 'varchar';
	} elsif ($type eq 'smallint') {
	    $type = 'int';
	} elsif ( $type eq 'uniqueidentifier' ) {
            $type = 'CHAR(38)';
	    $size = ''
        } elsif ( $type eq 'bit' or $type eq 'bool' or $type eq 'boolean') {
	    $type = 'BOOLEAN';
	    $size = '';
	} elsif ( $type eq 'float' ) {
	    $type = 'FLOAT';
	    $size = '';
	} elsif ( $type eq 'datetime2' ) {
	    $type = 'datetime';
	    $size = '';
	}
	if ($type ne 'varchar' && $type ne 'varbinary') {
	    $size = '';
	} elsif (!defined($size)) {
	    $size = 1024;
	}
	my $coldecl = {
	    'name' => $c,
		'type' => $type,
		'size' => $size,
		'key' => $key,
		'unique' => $unique,
		'index' => $index,
		'autoincrement' => $autoincrement
	};
	if ($type eq 'date') {
	    $coldecl->{tmpname} = "\@tmp_date_$count";
	    $coldecl->{conversion} = "IF($coldecl->{tmpname} = '', NULL, " . $DATE_STRTODATE->($coldecl->{tmpname}) . ")";
	} elsif ($type eq 'datetime') {
	    $coldecl->{tmpname} = "\@tmp_datetime_$count";
	    $coldecl->{conversion} = "IF($coldecl->{tmpname} = '', NULL, " . $DATETIME_STRTODATE->($coldecl->{tmpname}) .")";
	} elsif ($type eq 'time') {
	    $coldecl->{tmpname} = "\@tmp_time_$count";
	    $coldecl->{conversion} = "IF($coldecl->{tmpname} = '', NULL, " . $TIME_STRTODATE->($coldecl->{tmpname}) . ")";
	} elsif ($type eq 'int') {
	    $coldecl->{tmpname} = "\@tmp_int_$count";
	    $coldecl->{conversion} = "NULLIF($coldecl->{tmpname}, '')";
	} elsif ($type eq 'BOOLEAN') {
	    $coldecl->{type} = 'boolean';
	    $coldecl->{tmpname} = "\@tmp_int_$count";
	    $coldecl->{conversion} = bool_conversion($coldecl->{tmpname});
	}
	if (defined($size)) {
	    $coldecl->{size} = $size;
	}
	push @columns, $coldecl;
	$count++;
    }
    my $columndelimiter = $opt->columndelimiter;
    $columndelimiter =~ s/	/\\t/g;
    my $rowdelim = $opt->rowdelimiter;
    if ($rowdelim) {
        $rowdelim =~ s/\n/\\n/g;
	$rowdelim =~ s/\r/\\r/g;
    }
    if (scalar(@columns) == 0) {
	print STDERR "No columns on table $table\n";
	print STDERR Dumper($csvfiles->{$table});
	print STDERR Dumper($specfiles->{$table}->{columns});
	exit(1);
    }
    
    my $vars = {
	'dirs' => $opt->dir,
	    'tablename' => $table,
	    'columns' => \@columns,
	    'sep' => $columndelimiter,
	    'ext' => $opt->ext,
	    'enc' => $ttenc,
	    'headerrows' => $opt->headerrows
    };

    

    if (defined($rowdelim)) {
	$vars->{rowsep} = $rowdelim;
    }
    if (defined($opt->quote) && $opt->quote ne '') {
	$vars->{quote} = $opt->quote;
    }
    if (defined($opt->escape) && $opt->escape ne '') {
	$vars->{escape} = $opt->escape;
    }

    $tt2->process( 'create_tables.tt', $vars, \*STDOUT,  {binmode => ':utf8' } ) || die $tt2->error();

}

=head1 AUTHOR

Magnus Enger, Libriotech

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
