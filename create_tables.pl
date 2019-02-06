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
    micromarc => '%Y-%m-%d'
    );

my %DATETIME_FORMATS = (
    bookit => '%d-%b-%y %T',
    libra  => '%Y%m%d %T',
    #micromarc => '%d.%m.%Y %H.%i.%S'
    micromarc => '%Y-%m-%d %H:%i:%S'
    );

my %TIME_FORMATS = (
    bookit => '%T',
    libra  => '%T',
    #micromarc => '%H.%i.%S'
    micromarc => '%H:%i:%S'
    );

my ($opt, $usage) = describe_options(
    '%c %o <some-arg>',
    [ 'tables=s@', "tables to create", { required => 1  } ],
    [ 'format=s', 'Source format', { default => 'libra' } ],
    [ 'spec=s',    'spec directory',   { required => 1 } ],
    [ 'dir=s',     'tables directory', { required => 1 } ],
    [ 'ext=s',     'table filename extension', { default => '.txt' } ],
    [ 'columndelimiter=s', 'column delimiter',  { default => '!*!' } ],
    [ 'rowdelimiter=s',  'row delimiter'      ],
    [ 'encoding=s',  'character encoding',      { default => 'utf-8' } ],
    [ 'specencoding=s',  'character encoding of specfile',      { default => 'utf-8' } ],
    [ 'quote=s',  'quote character' ],
    [ 'escape=s', 'escape character', { default => "\\" } ],
    [ 'headerrows=i', 'number of header rows',  { default => 0 } ],
           [],
           [ 'verbose|v',  "print extra stuff"            ],
           [ 'help',       "print usage message and exit", { shortcircuit => 1 } ],
         );

print $usage->text if ($opt->help);

my  ($csvfiles, $specfiles, $missingcsvs, $missingspecs) =
    build_table_info($opt);

my $DATE_STRTODATE = strtodate($DATE_FORMATS{$opt->format});
my $DATETIME_STRTODATE = strtodate($DATETIME_FORMATS{$opt->format});
my $TIME_STRTODATE = strtodate($TIME_FORMATS{$opt->format});

sub bool_conversion {
    my $s = shift;

    return "IF($s = '', NULL, IF($s REGEXP '^(T(rue)?)|(Y(es))\$', TRUE, FALSE))";
}

sub strtodate {
    my $f = shift;
    if ($f =~ /%y/) {
	# Two digit years.  Only support dates up to one year into the future.
	return sub {
	    my $s = shift;
	    return "IF (STR_TO_DATE($s, '" .
		$f ."') > ADDDATE(CURRENT_DATE(), INTERVAL 1 YEAR), ADDDATE(STR_TO_DATE($s, '" .
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

    if (1 && $opt->verbose) {
	print STDERR "Creating table $table\n";
    }
    
    die "No spec file for $table" unless defined($specfiles->{$table});
    my $specfile = $opt->spec . '/' . $specfiles->{$table}->{filename};

    my $count = 0;
    my @columns = ();
	
    for my $c (@{$csvfiles->{$table}->{columnlist}}) {
	my $s = $specfiles->{$table}->{columns}->{$c};
	if (! defined($s->{type})) {
	    # print Dumper($specfiles);
	}
	
	my $type = $s->{type};
	if (!defined($type)) {
	    $type = '';
	} else {
	    chomp $type;
	}
	my $size;
	if (defined($s->{typeextra}) and $s->{typeextra} ne '') {
	    $size = $s->{typeextra};
	}
	if ($type eq 'nvarchar') {
	    $type = 'varchar';
	} elsif ($type eq 'smallint') {
	    $type = 'int';
	} elsif ( $type eq 'uniqueidentifier' ) {
            $type = 'CHAR(38)';
	    $size = ''
        } elsif ( $type eq 'bit' ) {
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
		'size' => $size
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
    $rowdelim =~ s/\n/\\n/g;
    $rowdelim =~ s/\r/\\r/g;
    my $vars = {
	'dirs' => $opt->dir,
	    'tablename' => $table,
	    'columns' => \@columns,
	    'sep' => $columndelimiter,
	    'rowsep' => $rowdelim,
	    'ext' => $opt->ext,
	    'enc' => $ttenc,
	    'headerrows' => $opt->headerrows
    };
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
