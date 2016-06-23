#!/usr/bin/env perl

use File::Copy;
use Modern::Perl;

say "Usage: $0 <path to Borrowers.txt> <path to fixed Borrowers.txt>" unless $ARGV[0] and $ARGV[1];
my $filename = $ARGV[0];
my $outfilename = $ARGV[1];

open (my $fh, "<:encoding(utf-16):crlf", $filename);
open (my $outfh, ">:encoding(utf-16):crlf", $outfilename);

my $count = 0;
my $current_line = '';
$/ = "!*!0\n";

while (my $line = <$fh> ) {

    local $/ = "\n";

    chomp $line;
    next if $line eq '';

    $current_line .= $line;

    my @parts = split ('!\*!', $line);

    say "Parts: " . +@parts;

    my $last_char = substr $line, -1;
    if ( $last_char eq '0' ) {
        # say '-->' . $current_line . '<--';
	print $outfh $current_line . "\x1e";
        $current_line = '';
    }

    $count++;
    # exit if $count == 100;
}

