#!/usr/bin/perl

use File::Slurper qw( read_lines write_text );
use File::Copy;
use Modern::Perl;
$/ = "\r\n";

say "Usage: $0 /path/to/Borrowers.txt" unless $ARGV[0];
my $filename = $ARGV[0];
my $tmp_file = '/tmp/borrowers.txt';

my @lines = read_lines( $filename );

my $count = 0;
my $current_line = '';
my $out;
foreach my $line ( @lines ) {

    chomp $line;
    next if $line eq '';

    $current_line .= $line;
    my $last_char = substr $line, -1;
    if ( $last_char eq '0' ) {
        # say '-->' . $current_line . '<--';
        $out .= $current_line . "\r\n";
        $current_line = '';
    }

    $count++;
    # exit if $count == 100;

}

write_text( $tmp_file, $out, 'UTF-8', 'clrf' => 1 );
move( $tmp_file, $filename );
