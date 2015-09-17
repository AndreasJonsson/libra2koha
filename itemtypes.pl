#!/usr/bin/perl 
 
# Copyright 2015 Magnus Enger Libriotech
 
=head1 NAME

itemtypes.pl - Test mapping from 00x codes to Koha itemtypes.

=head1 SYNOPSIS

 perl itemtypes.pl -i /path/to/records.marcxml -l 100

=cut

use MARC::File::XML ( BinaryEncoding => 'utf8', RecordFormat => 'NORMARC' );
use Getopt::Long;
use Data::Dumper;
use Pod::Usage;
use Modern::Perl;
require "lib/Itemtypes.pm";

binmode STDOUT, ":utf8";
$|=1; # Flush output

# Get options
my ( $input_file, $itype_limit, $limit, $verbose, $debug ) = get_options();

# Check that the input file exists
if ( !-e $input_file ) {
    print "The file $input_file does not exist...\n";
    exit;
}

my $batch = MARC::File::XML->in( $input_file );
my $count = 0;
my %itemtype_count;
RECORD: while (my $record = $batch->next()) {

    my $itemtype = get_itemtype( $record );

    say "$itemtype " . _book_info( $record ) if $verbose;
    say _book_info( $record ) if $itype_limit && $itype_limit eq $itemtype;
    $itemtype_count{ $itemtype }++;

    # Count and cut off at the limit if one is given
    $count++;
    last if $limit && $limit == $count;

} # end foreach record

say "   $count records done\n";

my $sum = 0;
foreach my $key ( sort keys %itemtype_count ) {

    say "   $key " . $itemtype_count{ $key };
    $sum += $itemtype_count{ $key };

};

say "Sum: $sum";

## Internal subroutines.

sub _book_info {

    my ( $record ) = @_;

    my $out;
    if ( $record->field( '003' ) && $record->field( '003' )->data() ) {
        $out .= $record->field( '003' )->data();
    }
    if ( $record->field( '001' ) && $record->field( '001' )->data() ) {
        $out .= $record->field( '001' )->data();
    }
    $out .= ' ';
    if ( $record->field( '000' ) && $record->field( '000' )->data() ) {
        $out .= '000="' . $record->field( '000' )->data() . '" ';
    }
    if ( $record->field( '006' ) && $record->field( '006' )->data() ) {
        $out .= '006="' . $record->field( '006' )->data() . '" ';
    }
    if ( $record->field( '007' ) && $record->field( '007' )->data() ) {
        $out .= '007="' . $record->field( '007' )->data() . '" ';
    }
    if ( $record->field( '008' ) && $record->field( '008' )->data() ) {
        $out .= '008="' . $record->field( '008' )->data() . '" ';
    }
    if ( $record->title() ) {
        $out .= $record->title();
    }
    if ( $record->subfield( '245', 'h' ) ) {
        $out .= " || 245h: " . $record->subfield( '245', 'h' );
    }
    if ( $record->subfield( '852', 'c' ) ) {
        $out .= " 852c: " . $record->subfield( '852', 'c' );
    }
    if ( $record->subfield( '852', 'h' ) ) {
        $out .= " 852h: " . $record->subfield( '852', 'h' );
    }
    return $out;

}

=head1 OPTIONS

=over 4

=item B<-i, --infile>

Path to MARCXML input file.

=item B<-l, --limit>

Only process the n first records.

=item B<-v --verbose>

Output one line per record, giving the itemtype, 000, 001, 003, 006, 007, 008,
title and 245h. 

Without this option the only output is a summary of the different itemtype codes
and how often they occur. 

=item B<-d --debug>

Even more verbose output.

=item B<-h, -?, --help>

Prints this help message and exits.

=back
                                                               
=cut
 
sub get_options {
 
    # Options
    my $input_file  = '';
    my $itype_limit = '';
    my $limit       = '';
    my $verbose     = '';
    my $debug       = '';
    my $help        = '';
 
    GetOptions (
        'i|infile=s'   => \$input_file,
        't|itemtype=s' => \$itype_limit,
        'l|limit=i'    => \$limit,
        'v|verbose'    => \$verbose,
        'd|debug'      => \$debug,
        'h|?|help'     => \$help
    );
 
    pod2usage( -exitval => 0 ) if $help;
    pod2usage( -msg => "\nMissing Argument: -i, --infile required\n",  -exitval => 1 ) if !$input_file;
 
    return ( $input_file, $itype_limit, $limit, $verbose, $debug );
 
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
