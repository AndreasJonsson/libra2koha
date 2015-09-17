#!/usr/bin/perl 
 
# Copyright 2015 Magnus Enger Libriotech
 
=head1 NAME

analyze00x.pl - Read MARCXML records from a file and add items from the database.

=head1 SYNOPSIS

 perl analyze00x.pl -v

=cut

use MARC::File::XML ( BinaryEncoding => 'utf8', RecordFormat => 'NORMARC' );
use Getopt::Long;
use Data::Dumper;
use Pod::Usage;
use Modern::Perl;

binmode STDOUT, ":utf8";
$|=1; # Flush output

# Get options
my ( $input_file, $limit, $verbose, $debug ) = get_options();

# Check that the input file exists
if ( !-e $input_file ) {
    print "The file $input_file does not exist...\n";
    exit;
}

my $batch = MARC::File::XML->in( $input_file );
my $count = 0;
my %codes;
RECORD: while (my $record = $batch->next()) {

    my $f000p6 = get_pos( '000', 6, $record );
    my $f006p0 = get_pos( '006', 0, $record );
    my $f007p0 = get_pos( '007', 0, $record );
    $codes{ $f000p6 . $f006p0 . $f007p0 }++;
    
    # Count and cut off at the limit if one is given
    $count++;
    last if $limit && $limit == $count;

} # end foreach record

say "$count records done";

my $sum = 0;
foreach my $key ( sort keys %codes ) {

    say "$key " . $codes{ $key };
    $sum += $codes{ $key };

};

say "Sum: $sum";

## Internal subroutines.

# Takes: A string
# Returns: the char at the given position

sub get_pos {

    my ( $field, $pos, $record ) = @_;
    if ( $record->field( $field ) && $record->field( $field )->data() ) {
        my $string = $record->field( $field )->data();
        my @chars = split //, $string;
        return $chars[ $pos ];
    } else {
        return '_';
    }

}

=head1 OPTIONS

=over 4

=item B<-i, --infile>

Path to MARCXML input file.

=item B<-l, --limit>

Only process the n first somethings.

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
    my $input_file  = '';
    my $limit       = '';
    my $verbose     = '';
    my $debug       = '';
    my $help        = '';
 
    GetOptions (
        'i|infile=s'  => \$input_file,
        'l|limit=i'   => \$limit,
        'v|verbose'   => \$verbose,
        'd|debug'     => \$debug,
        'h|?|help'    => \$help
    );
 
    pod2usage( -exitval => 0 ) if $help;
    pod2usage( -msg => "\nMissing Argument: -i, --infile required\n",  -exitval => 1 ) if !$input_file;
 
    return ( $input_file, $limit, $verbose, $debug );
 
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
