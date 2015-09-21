#!/usr/bin/perl

# Copyright 2015 Magnus Enger Libriotech

=encoding utf8

=head1 NAME

table2config.pl - Helper script for turning a table into a YAML config file.

=head1 SYNOPSIS

  perl table2config.pl /path/to/tablename.txt 0 2

=head1 DESCRIPTION

Takes three arguments: 

=over 4

=item * A path to a table file, e.g. Something.txt (not Somethingspec.txt)

=item * The position of the column that should be turned into the key

=item * The position of the column that should be turned into a comment

=back

So with this file as the starting point ("!*!" is the field separator): 

  1!*!01!*!Barn!*!^@!*!^@!*!-1!*!^@!*!20071121!*!12:53:37!*!libra!*!20091105!*!14:02:02!*!kran
  2!*!02!*!Vuxen!*!^@!*!^@!*!0!*!^@!*!20071121!*!12:53:37!*!libra!*!!*!!*!
  3!*!08!*!Referens!*!^@!*!^@!*!0!*!^@!*!20071121!*!12:53:37!*!libra!*!!*!!*!
  4!*!eHub!*!E-lån!*!E-lån!*!E-lån!*!0!*!^@!*!20140109!*!13:35:51!*!libra!*!!*!!*!

and this invocation of the script: 

  perl table2config.pl /path/to/Departments.txt 0 2 > ccode.yaml

the outout will look like this: 

  ---
  # Generated from /home/magnus/Nedlastinger/molndal/Koha/utf8/Departments.txt
  # 2015-09-21 08:14:38
  1: '' # Barn
  2: '' # Vuxen
  3: '' # Referens
  4: '' # E-lån

The empty values will now have to be filled in by hand, before F<ccode.yaml> can
be used as a config file by F<records.pl>

=cut

use DateTime;
use File::Slurper qw( read_lines );
use Modern::Perl;

my $dt = DateTime->now( time_zone => 'Europe/Oslo' );

my @lines = read_lines( $ARGV[0], 'utf8', chomp => 1 );

say "---";
say "# Generated from $ARGV[0]";
say "# " . $dt->ymd . ' ' . $dt->hms;
say ''  ;

foreach my $line ( @lines ) {

    my @fields = split /!\*!/, $line;
    my $key     = $fields[ $ARGV[1] ];
    my $comment = $fields[ $ARGV[2] ];
    say "$key: '' # $comment";

}
