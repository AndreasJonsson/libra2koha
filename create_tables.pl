#!/usr/bin/env perl 

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

my ($opt, $usage) = describe_options(
    '%c %o <some-arg>',
    [ 'tables=s@', "tables to create", { required => 1  } ],
    [ 'spec=s',    'spec directory',   { required => 1 } ],
    [ 'dir=s',     'tables directory', { required => 1 } ],
    [ 'ext=s',     'table filename extension', { default => '.txt' } ],
    [ 'columndelimiter=s', 'column delimiter',  { default => '!*!' } ],
    [ 'rowdelimiter=s',  'row delimiter'      ],
    [ 'encoding=s',  'character encoding',      { default => 'utf-16' } ],
    [ 'specencoding=s',  'character encoding of specfile',      { default => 'utf-16' } ],
    [ 'quote=s',  'quote character' ],
    [ 'headerrows=i', 'number of header rows',  { default => 0 } ],
           [],
           [ 'verbose|v',  "print extra stuff"            ],
           [ 'help',       "print usage message and exit", { shortcircuit => 1 } ],
         );

print $usage->text if ($opt->help);

my  ($csvfiles, $specfiles, $missingcsvs, $missingspecs) =
    build_table_info($opt);

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

    my @columns = ();
    for my $c (@{$csvfiles->{$table}->{columnlist}}) {
	my $s = $specfiles->{$table}->{columns}->{$c};
	my $type = $s->{type};
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
	}
	if ($type ne 'varchar') {
	    $size = '';
	}
	my $coldecl = {
	    'name' => $c,
		'type' => $type,
		'size' => $size
	};
	if (defined($size)) {
	    $coldecl->{size} = $size;
	}
	push @columns, $coldecl;
    }
    my $columndelimiter = $opt->columndelimiter;
    $columndelimiter =~ s/	/\\t/g;
    my $vars = {
	'dirs' => $opt->dir,
	    'tablename' => $table,
	    'columns' => \@columns,
	    'sep' => $columndelimiter,
	    'rowsep' => $opt->rowdelimiter,
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
