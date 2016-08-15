#!/usr/bin/env perl 

# Copyright 2014 Magnus Enger Libriotech

=head1 NAME

create_tables.pl - Create database tables.

=head1 SYNOPSIS

 perl create_tables.pl --dir /path/to/export -v > tables.sql

=head1 DESCRIPTION

This script ingests the *spec.txt files from the Libra export and produces
corresponding "CREATE TABLE" SQL statements, written to STDOUT. 

=cut

use File::Find::Rule;
use File::Basename;
use Getopt::Long;
use Data::Dumper;
use Template;
use DateTime;
use Pod::Usage;
use Modern::Perl;

# Get options
my ( $dir, $tables, $verbose, $debug ) = get_options();
my $indir = $dir;

# Check that the file exists
if ( !-d $indir ) {
    print "The directory $indir does not exist! Did you run prep.sh?\n";
    exit;
}

# Configure Template Toolkit
my $ttconfig = {
    INCLUDE_PATH => '', 
    ENCODING => 'utf8'  # ensure correct encoding
};
# create Template object
my $tt2 = Template->new( $ttconfig ) || die Template->error(), "\n";

# Find all the *spec.txt files and turn them into database tables
my @files = File::Find::Rule->file()->name( '*spec.txt' )->in( $indir );
foreach my $file ( @files ) {

    # Get the name of the table
    my( $filename, $dirs, $suffix ) = fileparse( $file );
    my $tablename = substr( $filename, 0, -8 );

    # Only do the tables we will actually use
    next unless ( index( $tables, $tablename ) >= 0 );

    # Get the columns
    my @columns;
    open(my $fh, "<:encoding(UTF-8):crlf", $file) or die "Couldn't open $file: $!";
    while(my $line = <$fh> ) {
        chomp($line);
        my ( $name, $type, $size ) = split /\t/, $line;
        if ( $type eq 'uniqueidentifier' ) {
            $type = 'CHAR(38)';
        }
        push @columns, { 'name' => $name, 'type' => $type, 'size' => "$size" };
    }
    close $fh;
    my $vars = { 'dirs' => $dirs, 'tablename' => $tablename, 'columns' => \@columns };
    $tt2->process( 'create_tables.tt', $vars, \*STDOUT,  {binmode => ':utf8'} ) || die $tt2->error();

}

# Special treatment for exportCatMatch, which does not have a *spec.txt file
if ( index( $tables, 'exportCatMatch' ) >= 0 ) {

    # Special treatment for exportCatMatch.txt
    my @columns;
    push @columns, { 'name' => 'IdCat', 'type' => 'int', 'size' => '12' };
    push @columns, { 'name' => 'ThreeOne', 'type' => 'char', 'size' => '32' };
    my $vars = { 'dirs' => "$dir/", 'tablename' => 'exportCatMatch', 'columns' => \@columns, 'sep' => ', ', 'rowsep' => '\r\n' };
    $tt2->process( 'create_tables.tt', $vars, \*STDOUT,  {binmode => ':utf8'} ) || die $tt2->error();

}

=head1 OPTIONS

=over 4

=item B<--dir>

Directory that contains files exported from Libra.

=item B<-t, --tables>

List of tables that should be considered in this pass. Separate table names with
the vertical bar character. E.g.: 

  perl create_tables.pl --tables exportCatMatch|Items|BarCodes|StatusCodes

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
    my $dir     = '';
    my $tables  = '';
    my $verbose = '';
    my $debug   = '';
    my $help    = '';

    GetOptions (
        'dir=s'      => \$dir,
        't|tables=s' => \$tables,
        'v|verbose'  => \$verbose,
        'd|debug'    => \$debug,
        'h|?|help'   => \$help
    );

    pod2usage( -exitval => 0 ) if $help;
    pod2usage( -msg => "\nMissing Argument: --dir required\n", -exitval => 1 ) if !$dir;
    pod2usage( -msg => "\nMissing Argument: -t, --tables required\n", -exitval => 1 ) if !$tables;

    return ( $dir, $tables, $verbose, $debug );

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
