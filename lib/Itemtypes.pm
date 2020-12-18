package Itemtypes;

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(get_itemtype);
@EXPORT_OK   = qw();

use Modern::Perl;
use Marc21Utils;
use RecordUtils;

use Data::Dumper;

package Itemtypes;


my %itemtypes;
my %ldr6_table;

                    # | ldr6 | ldr7 | 0070 | 0071 | 0074 | 00710 | 00821 | 00824 | 00825 | 00826 | 00827 |

my @match_score = ( 100, 1, 10, 1, 1, 1, 1, 1, 1, 1, 1 );

sub match_score {
    my ($a, $b) = @_;

    if (length($a) != length($b) || length($a) != scalar(@match_score)) {
        warn "Incorrect string length in match_score!";
        return -1;
    }

    my $score = 0;

    for (my $i = 0; $i < length($a); $i++) {
        my $ca = substr($a, $i, 1);
        my $cb = substr($b, $i, 1);

        if ($ca ne '*' && $cb ne '*') {
            if ($ca eq $cb) {
                $score += $match_score[$i];
            } else {
                return -1;
            }
        }
    }

    return $score;
};

sub get_itemtype {

    # Takes: A MARC record
    # Returns: An appropriate itemtype for the record

    my ( $record ) = @_;

    # Pick out all the codes we need to make our decisions
    our $f000p0  = get_pos( '000', 0,  $record );
    our $f000p1  = get_pos( '000', 1,  $record );
    our $f000p6  = get_pos( '000', 6,  $record );
    our $f000p7  = get_pos( '000', 7,  $record );
    our $f006p0  = get_pos( '006', 0,  $record );
    our $f006p4  = get_pos( '006', 4,  $record );
    our $f006p9  = get_pos( '006', 9,  $record );
    our $f007p0  = get_pos( '007', 0,  $record );
    our $f007p1  = get_pos( '007', 1,  $record );
    our $f007p4  = get_pos( '007', 4,  $record );
    our $f007p10 = get_pos( '007', 10, $record );
    our $f008p21 = get_pos( '008', 21, $record );
    our $f008p24 = get_pos( '008', 24, $record );
    our $f008p25 = get_pos( '008', 25, $record );
    our $f008p26 = get_pos( '008', 26, $record );
    our $f008p27 = get_pos( '008', 27, $record );

    my %fieldpositions = (
       'f000p0' => $f000p0,
       'f000p1' => $f000p1,
       'f000p6' => $f000p6,
       'f000p7' => $f000p7,
       'f006p0' => $f006p0,
       'f006p4' => $f006p4,
       'f006p9' => $f006p9,
       'f007p0' => $f007p0,
       'f007p1' => $f007p1,
       'f007p4' => $f007p4,
       'f007p10' => $f007p10,
       'f008p21' => $f008p21,
       'f008p24' => $f008p24,
       'f008p25' => $f008p25,
       'f008p26' => $f008p26,
       'f008p27' => $f008p27,
    );


    my $k = '';

    my $a = sub {
        my $c = shift;
        if (length($c) != 1 || $c eq ' ' || $c eq '|' || $c eq '_' || $c eq '-') {
            $c = '*';
        }

        $k .= $c;
    };

    # | ldr6 | ldr7 | 0070 | 0071 | 0074 | 00710 | 00821 | 00824 | 00825 | 00826 | 00827 |

    $a->($f000p6);
    $a->($f000p7);
    $a->($f007p0);
    $a->($f007p1);
    $a->($f007p4);
    $a->($f007p10);
    $a->($f008p21);
    $a->($f008p24);
    $a->($f008p25);
    $a->($f008p26);
    $a->($f008p27);


    my $match_set = $ldr6_table{$f000p6};

    my $max_score = -1;
    my $match;

    for my $s (@$match_set) {
        my $score = match_score($s, $k);
        if ($score > $max_score) {
            $max_score = $score;
            $match = $s;
        }
    }

    if ($max_score < 0) {
        warn "No itemtype match were found for record with key '$k'!";
        return 'X';
    }

    return $itemtypes{$match};

    if ($main::debug) {
        print STDERR Dumper(\%fieldpositions);
    }

    my $itemtype = 'X';

    my $electronic_resource  = sub {
        if ( $record->field( '500' ) ) {
            foreach my $f500 ( $record->field( '500' ) ) {
                my $f500a = $f500->subfield( 'a' );
                if ( $f500a =~ m/Nintendo DS/ ) {
                    return 'DS';
                }
            }
        }
        if ( $f006p9 eq 'g' || $f008p26 eq 'g' ) {
            return "TV-SPEL";
        } elsif ( $f008p26 eq 'j' ) {
            return "DATABAS";
        } elsif ( $record->field( '500' ) && $record->subfield( '500', 'a' ) ) {
            foreach my $note ( $record->subfield( '500', 'a' ) ) {
                if ( $note =~ m/Spr.kkurs/gi ) {
                    return "SPRAK-CD";
                }
            }
        } else {
            return "CD-ROM";
        }

        return "DATAFIL";
    };


    # Taktila resurser
    # http://www.kb.se/katalogisering/Formathandboken/Bibliografiska-formatet/007/Taktilt-material/
    if ( $f007p0 eq 'f' ) {
        $itemtype = 'PUNKT';

    # Musikalisk resurs eller ljudupptagning
    # http://www.kb.se/katalogisering/Formathandboken/Bibliografiska-formatet/008/Musikalisk-resurs/
    } elsif ( $f000p6 eq 'c' || $f000p6 eq 'd' ) {
        $itemtype = 'MUSIK';

    } elsif ( $f000p6 eq 'j' ) {
	if ( $f007p0 eq 's' ) {
	    if ( $f007p1 eq 's' ) {
		$itemtype = 'KASSETT';
	    } elsif ( $f007p1 eq 'd' && $f007p10 eq 'm' ) {
		$itemtype = 'MUSIKCD';
	    } elsif ( $f007p1 eq 'd' && $f007p10 eq 'p' ) {
		$itemtype = 'MUSIKLP';
	    } else {
		$itemtype = "MUSIKCD";
	    }
	} else {
	    $itemtype = "MUSIKCD";
	}
    } elsif ($f007p0 eq 's' && $f007p1 eq 'd') {
	$itemtype = 'TALBOK';
    } elsif ($f007p0 eq 't' && $f007p1 eq 'b') {
	$itemtype = 'STORSTIL';
    # Spelfilmer
    # http://www.kb.se/katalogisering/Formathandboken/Bibliografiska-formatet/007/Spelfilm/
    # http://www.kb.se/katalogisering/Formathandboken/Bibliografiska-formatet/008/Grafisk-resurs-/
    # http://www.kb.se/katalogisering/Formathandboken/Bibliografiska-formatet/007/Videoupptagningar/
    } elsif ( $f007p0 eq 'v' ) {
        if ( $f007p4 eq 'b' ) {
            $itemtype = 'VHS';
        } elsif ( $f007p4 eq 's' ) {
            $itemtype = 'BLURAY';
        } elsif ( $f007p4 eq 'v' ) {
            $itemtype = 'FILM';
        } else {
            $itemtype = 'FILM';
        }

    # Ljudbok
    } elsif ( $record->subfield( '852', 'c' ) && $record->subfield( '852', 'c' ) =~ m/LJUDBOK CD Mp3/gi ) {
        $itemtype = 'MP3';
    } elsif ( $record->subfield( '852', 'h' ) && $record->subfield( '852', 'h' ) =~ m/LJUDBOK CD Mp3/gi ) {
        $itemtype = 'MP3';
    } elsif ( $record->subfield( '500', 'a' ) && $record->subfield( '500', 'a' ) =~ m/ljudbok mp3/gi ) {
        $itemtype = 'MP3';
    } elsif ( $f000p6 eq 'i' && $f000p7 eq 'm' && $f007p0 eq 's' && $f007p1 eq 'd' ) {
            $itemtype = 'LJUDBOK';
    } elsif (
        $record->field( '852' ) && (
            ( $record->subfield( '852', 'c' ) && $record->subfield( '852', 'c' ) =~ m/DAISY/gi ) ||
            ( $record->subfield( '852', 'h' ) && $record->subfield( '852', 'h' ) =~ m/DAISY/gi )
        )
    ) {
        $itemtype = 'TALBOK';
    } elsif ( $record->subfield( '852', 'h' ) && $record->subfield( '852', 'h' ) =~ m/ljudbok/gi ) {
        $itemtype = 'LJUDBOK';
    } elsif ( $record->subfield( '852', 'h' ) && $record->subfield( '852', 'h' ) =~ m/talböcker/gi ) {
        $itemtype = 'LJUDBOK';

    # Avhandlingar
    } elsif ( $f008p24 eq 'm' || $f008p25 eq 'm' || $f008p26 eq 'm' || $f008p27 eq 'm' ) {
        $itemtype = 'AVHANDLING';

    # E-bok
    } elsif ( $f000p6 eq 'a' && $f000p7 eq 'm' && $f007p0 eq 'c' && $f007p1 eq 'r' ) {
        $itemtype = 'EBOK';

    # Fortlöpande resurs i form av text
    # http://www.kb.se/katalogisering/Formathandboken/Bibliografiska-formatet/008/Fortlopande-resurs/
    } elsif (
        ( $f000p6 eq 'a' || $f000p6 eq 't' ) &&
        ( $f000p7 eq 'b' || $f000p7 eq 'i' || $f000p7 eq 's' )
    ) {
        if ( $f008p21 eq 'p' ) {
            $itemtype = 'TIDSKRIFT';
        } elsif ( $f006p4 eq '_' || $f008p21 eq '_' ) {
            $itemtype = "AARSBOK";
        } elsif ( $f008p21 eq 'n' ) {
            $itemtype = "TIDNINGAR";
        }

    # Elektronisk resurs
    # http://www.kb.se/katalogisering/Formathandboken/Bibliografiska-formatet/008/Elektronisk-resurs-/
    } elsif ( $f000p6 eq 'm' || $f006p0 eq 'm' ) {
        $itemtype = $electronic_resource->();
    } elsif ( $record->subfield( '852', 'c' ) && $record->subfield( '852', 'c' ) =~ m/TV-SPEL.*/ ) {
        $itemtype = "TV-SPEL";

    # Kartografisk resurs
    # http://www.kb.se/katalogisering/Formathandboken/Bibliografiska-formatet/008/Kartografisk-resurs/
    } elsif ( $f000p6 eq 'e' || $f000p6 eq 'f' ) {
        $itemtype = 'KARTA';

    # Daisy
    # http://libra-hjalp.axiell.com/daisy
    } elsif ( $f000p6 eq 'i' && $f007p0 eq 'c' ) {
        $itemtype = 'TALBOK';

    # Monografisk resurs i form av mångfaldigad text
    # http://www.kb.se/katalogisering/Formathandboken/Bibliografiska-formatet/008/Monografisk-resurs/
    } elsif (
        ( $f000p6 eq 'a' || $f000p6 eq 't' ) &&
        ( $f000p7 ne 'b' && $f000p7 ne 'i' && $f000p7 ne 's' )
    ) {
        $itemtype = 'BOK';
    } elsif ( $f000p6 eq 'p' ) {
        $itemtype = 'BLANDAT';
    } elsif ( $f000p6 eq 'o' ) {
        $itemtype = 'PAKET';
    } elsif ( $f000p6 eq 'g' ) {
       $itemtype = 'PROJEKTION';
    } elsif ( $f000p6 eq 'k' ) {
        $itemtype = '2DEJPROJGR';
    }

    if ($itemtype eq 'X') {
        # say STDERR "Failed to determine itemtype of this field:";
        # print STDERR Dumper(\%fieldpositions);
    }

    return $itemtype;

}

BEGIN {

=pod
+------+------+------+------+------+-------+-------+-------+-------+-------+-------+
| ldr6 | ldr7 | 0070 | 0071 | 0074 | 00710 | 00821 | 00824 | 00825 | 00826 | 00827 |
+------+------+------+------+------+-------+-------+-------+-------+-------+-------+
=cut

my $fields = <<'EOF';
| *    | *    | *    | *    | *    | *     | *     | *     | *     | *     | *     | UNKNOWN |
| *    | m    | *    | *    | *    | *     | *     | *     | *     | *     | *     | TEXT |
| a    | *    | *    | *    | *    | *     | *     | *     | *     | *     | *     | TEXT |
| a    | b    | *    | *    | *    | *     | *     | *     | *     | *     | *     | SERIAL |
| a    | m    | *    | *    | *    | *     | *     | *     | *     | *     | *     | TEXT |
| a    | m    | *    | *    | *    | *     | *     | 5     | *     | *     | *     | CALENDAR |
| a    | m    | *    | *    | *    | *     | *     | 6     | *     | *     | *     | COMICS |
| a    | m    | *    | *    | *    | *     | *     | a     | *     | *     | *     | ABSTRACT |
| a    | m    | *    | *    | *    | *     | *     | b     | *     | *     | *     | BIBLIOGRAPHY |
| a    | m    | *    | *    | *    | *     | *     | c     | *     | *     | *     | CATALOG |
| a    | m    | *    | *    | *    | *     | *     | d     | *     | *     | *     | DICTIONARY |
| a    | m    | *    | *    | *    | *     | *     | e     | *     | *     | *     | ENCYCLOPEDIA |
| a    | m    | *    | *    | *    | *     | *     | f     | *     | *     | *     | HANDBOOK |
| a    | m    | *    | *    | *    | *     | *     | m     | *     | *     | *     | THESES |
| a    | m    | *    | *    | *    | *     | *     | n     | *     | *     | *     | SURVEY |
| a    | m    | *    | *    | *    | *     | *     | y     | *     | *     | *     | YEARBOOK |
| a    | m    | c    | r    | *    | *     | *     | *     | *     | *     | *     | EREMOTE |
| a    | m    | c    | u    | *    | *     | *     | *     | *     | i     | *     | EUNSPECIFIED |
| a    | m    | f    | b    | *    | *     | *     | *     | *     | *     | *     | BRAILLE |
| a    | m    | s    | d    | *    | *     | *     | *     | *     | *     | *     | SOUNDDISC |
| a    | m    | t    | *    | *    | *     | *     | *     | *     | *     | *     | TEXT |
| a    | m    | t    | a    | *    | *     | *     | *     | *     | *     | *     | TEXT |
| a    | m    | t    | a    | *    | *     | *     | 6     | *     | *     | *     | COMICS |
| a    | m    | t    | a    | *    | *     | *     | b     | *     | *     | *     | BIBLIOGRAPHY |
| a    | m    | t    | a    | *    | *     | *     | d     | *     | *     | *     | DICTIONARY |
| a    | m    | t    | a    | *    | *     | *     | e     | *     | *     | *     | ENCYCLOPEDIA |
| a    | m    | t    | a    | *    | *     | *     | k     | *     | *     | *     | DISCOGRAPHY |
| a    | m    | t    | a    | *    | *     | *     | m     | *     | *     | *     | THESES |
| a    | m    | t    | a    | *    | *     | p     | *     | *     | *     | *     | TEXT |
| a    | m    | t    | b    | *    | *     | *     | *     | *     | *     | *     | LARGEPRINT |
| a    | m    | t    | u    | *    | *     | *     | *     | *     | *     | *     | TEXT |
| a    | s    | *    | *    | *    | *     | *     | *     | *     | *     | *     | SERIAL |
| a    | s    | *    | *    | *    | *     | m     | *     | *     | *     | *     | MONOGRAPHICSERIES |
| a    | s    | *    | *    | *    | *     | n     | *     | *     | *     | *     | NEWSPAPER |
| a    | s    | *    | *    | *    | *     | p     | *     | *     | *     | *     | PERIODIC |
| a    | s    | t    | a    | *    | *     | *     | *     | *     | *     | *     | SERIAL |
| a    | s    | t    | a    | *    | *     | *     | y     | *     | *     | *     | SERIALYEARBOOK |
| a    | s    | t    | a    | *    | *     | *     | y     | 6     | *     | *     | SERIALCOMIC |
| a    | s    | t    | a    | *    | *     | *     | y     | b     | *     | *     | SERIALBIBLIOGRAPHY |
| a    | s    | t    | a    | *    | *     | m     | *     | *     | *     | *     | MONOGRAPHICSERIES |
| a    | s    | t    | a    | *    | *     | n     | *     | *     | *     | *     | NEWSPAPER |
| a    | s    | t    | a    | *    | *     | p     | *     | *     | *     | *     | PERIODIC |
| a    | s    | t    | a    | *    | *     | p     | 6     | *     | *     | *     | PERIODICCOMIC |
| c    | m    | *    | *    | *    | *     | *     | *     | *     | *     | *     | NOTATEDMUSIC |
| c    | m    | q    | *    | *    | *     | *     | *     | *     | *     | *     | NOTATEDMUSIC |
| c    | m    | t    | a    | *    | *     | *     | *     | *     | *     | *     | TEXT |
| c    | s    | *    | *    | *    | *     | *     | y     | *     | *     | *     | SERIALNOTATEDMUSIC |
| d    | m    | t    | a    | *    | *     | *     | *     | *     | *     | *     | MANUSCRIPT |
| e    | m    | *    | *    | *    | *     | *     | *     | *     | *     | *     | CARTOGRAPHIC |
| f    | m    | *    | *    | *    | *     | *     | *     | *     | *     | *     | CARTOGRAPHIC |
| g    | m    | *    | *    | *    | *     | *     | *     | *     | *     | *     | PROJECTED |
| g    | s    | *    | *    | *    | *     | *     | *     | *     | *     | *     | PROJECTED |
| g    | m    | c    | r    | *    | *     | *     | *     | *     | *     | *     | EPROJECTED |
| g    | m    | v    | *    | *    | *     | *     | *     | *     | *     | *     | VIDEO |
| g    | m    | v    | *    | v    | *     | *     | *     | *     | *     | *     | DVD |
| g    | m    | v    | d    | *    | *     | *     | *     | *     | *     | *     | VIDEODISC |
| g    | m    | v    | d    | s    | *     | *     | *     | *     | *     | *     | BLUERAY |
| g    | m    | v    | d    | v    | *     | *     | *     | *     | *     | *     | DVD |
| g    | m    | v    | f    | b    | *     | *     | *     | *     | *     | *     | VHS |
| h    | m    | *    | *    | *    | *     | *     | *     | *     | *     | *     | UNKNOWN |
| i    | *    | s    | d    | *    | *     | *     | *     | *     | *     | *     | DISC |
| i    | m    | *    | *    | *    | *     | *     | *     | *     | *     | *     | NONMUSICSOUND |
| i    | m    | *    | *    | *    | *     | n     | *     | *     | *     | *     | NONMUSICSOUND |
| i    | m    | *    | o    | *    | *     | *     | *     | *     | *     | *     | DISC |
| i    | m    | c    | o    | *    | *     | *     | *     | *     | *     | *     | DISC |
| i    | m    | c    | o    | *    | *     | *     | *     | *     | m     | *     | DISC |
| i    | m    | c    | r    | *    | *     | *     | *     | *     | *     | *     | REMOTENONMUSICSOUND |
| i    | m    | s    | *    | *    | *     | *     | *     | *     | *     | *     | NONMUSICSOUND |
| i    | m    | s    | d    | *    | *     | *     | *     | *     | *     | *     | DISC |
| i    | m    | s    | d    | *    | *     | n     | *     | *     | *     | *     | DISC |
| i    | m    | s    | s    | *    | *     | *     | *     | *     | *     | *     | NONMUSICSOUND |
| i    | m    | s    | z    | *    | *     | n     | *     | *     | *     | *     | NONMUSICSOUND |
| i    | m    | t    | a    | *    | *     | *     | *     | *     | *     | *     | NONMUSICSOUND |
| i    | m    | v    | *    | b    | *     | *     | *     | *     | *     | *     | NONMUSICSOUND |
| i    | s    | s    | d    | *    | *     | m     | *     | *     | *     | *     | SERIALDISC |
| j    | m    | *    | *    | *    | *     | *     | *     | *     | *     | *     | MUSIC |
| j    | m    | *    | *    | *    | *     | n     | *     | *     | *     | *     | MUSIC |
| j    | m    | s    | *    | *    | *     | *     | *     | *     | *     | *     | MUSIC |
| j    | m    | s    | *    | *    | *     | n     | *     | *     | *     | *     | MUSICDISC |
| j    | m    | s    | d    | *    | *     | *     | *     | *     | *     | *     | MUSICDISC |
| j    | m    | v    | *    | b    | *     | *     | *     | *     | *     | *     | MUSICVIDEO |
| k    | m    | k    | j    | o    | *     | *     | *     | *     | *     | *     | NONPROJECTEDGRAPHIC |
| m    | m    | *    | *    | *    | *     | *     | *     | *     | *     | *     | COMPUTERFILE |
| m    | m    | *    | *    | *    | *     | *     | *     | *     | g     | *     | COMPUTERGAME |
| m    | m    | c    | *    | *    | *     | *     | *     | *     | g     | *     | COMPUTERGAME |
| m    | m    | c    | b    | *    | *     | *     | *     | *     | g     | *     | VIDEOGAME |
| m    | m    | c    | o    | *    | *     | *     | *     | *     | *     | *     | COMPUTERGAME |
| m    | m    | c    | o    | *    | *     | *     | *     | *     | g     | *     | COMPUTERGAME |
| m    | m    | c    | o    | *    | *     | *     | *     | *     | m     | *     | COMPUTERFILE |
| m    | m    | c    | o    | g    | *     | *     | *     | *     | i     | *     | COMPUTERFILE |
| m    | m    | c    | u    | *    | *     | *     | *     | *     | g     | *     | COMPUTERGAME |
| m    | m    | c    | u    | *    | *     | *     | *     | *     | i     | *     | COMPUTERFILE |
| o    | m    | *    | *    | *    | *     | *     | *     | *     | *     | *     | KIT |
| o    | m    | s    | d    | *    | *     | *     | *     | *     | *     | *     | KITDISC |
| o    | m    | s    | d    | *    | m     | *     | *     | *     | *     | *     | KITDISC |
| o    | m    | t    | a    | *    | *     | *     | *     | *     | *     | *     | KITTEXT |
| o    | m    | t    | a    | d    | *     | *     | *     | *     | *     | *     | KITTEXT |
| p    | m    | *    | *    | *    | *     | *     | *     | *     | *     | *     | MIXED |
| p    | m    | s    | d    | *    | *     | n     | *     | *     | *     | *     | MIXED |
| p    | s    | *    | *    | *    | *     | m     | *     | *     | *     | *     | SERIALMIXED |
| r    | m    | *    | *    | *    | *     | *     | *     | *     | *     | *     | 3DOBJECT |
| u    | n    | *    | *    | *    | *     | *     | *     | *     | *     | *     | UNKNOWN |
EOF

    %itemtypes = ();

    for my $line (split "\n", $fields) {
        my @parts = split '\|', $line, -1;
        my $key = '';
        for (my $i = 1; $i < scalar(@parts) - 2; $i++) {
            $key .= trim($parts[$i]);
        }

        $itemtypes{$key} = trim($parts[scalar(@parts) - 2]);
    }

    for my $key (keys %itemtypes) {
        my $c = substr($key, 0, 1);
        my $ks = $ldr6_table{$c};

        if (!defined $ks) {
            $ks = [];
            $ldr6_table{$c} = $ks;
        }

        push @$ks, $key;
    }

    my $wildcard = $ldr6_table{'*'};

    die "No wildcard rule for leader position 6!" if (!defined $wildcard);

    for my $c (keys %ldr6_table) {
        if ($c ne '*') {
            push @{$ldr6_table{$c}}, @$wildcard;
        }
    }
}


1;

=pod

    ExtractValue(metadata, '//datafield[@tag="852"]/subfield[@code="c"]') AS `852c`,
    ExtractValue(metadata, '//datafield[@tag="852"]/subfield[@code="h"]') AS `852h`,

DROP FUNCTION f;

DELIMITER $$
CREATE FUNCTION f(metadata LONGTEXT, xpath TINYTEXT, pos INT)
  RETURNS TINYTEXT
  DETERMINISTIC
BEGIN
  DECLARE t TINYTEXT;
  SELECT SUBSTRING(ExtractValue(metadata, xpath), pos + 1, 1)  INTO t;
  IF t IN (' ', '_', '-', '|') THEN
    RETURN '*';
  ELSE
    RETURN t;
  END IF;
END $$
DELIMITER ;

    f(metadata, '//controlfield[@tag="006"]', 0) AS `0060`,
    f(metadata, '//controlfield[@tag="006"]', 4) AS `0064`,
    f(metadata, '//controlfield[@tag="006"]', 9) AS `0069`,

SELECT
    f(metadata, '//leader', 6) AS `ldr6`,
    f(metadata, '//leader', 7) AS `ldr7`,
    f(metadata, '//controlfield[@tag="007"]', 0) AS `0070`,
    f(metadata, '//controlfield[@tag="007"]', 1) AS `0071`,
    f(metadata, '//controlfield[@tag="007"]', 4) AS `0074`,
    f(metadata, '//controlfield[@tag="007"]', 10) AS `00710`,
    f(metadata, '//controlfield[@tag="008"]', 21) AS `00821`,
    f(metadata, '//controlfield[@tag="008"]', 24) AS `00824`,
    f(metadata, '//controlfield[@tag="008"]', 25) AS `00825`,
    f(metadata, '//controlfield[@tag="008"]', 26) AS `00826`,
    f(metadata, '//controlfield[@tag="008"]', 27) AS `00827`,
    count(*)
FROM biblio_metadata
GROUP BY `ldr6`, `ldr7`, `0070`, `0071`, `0074`, `00710`, `00821`, `00824`, `00825`, `00826`, `00827`;


SELECT
    f(metadata, '//leader', 6) AS `ldr6`,
    f(metadata, '//leader', 7) AS `ldr7`,
    f(metadata, '//controlfield[@tag="007"]', 1) AS `0071`,
    f(metadata, '//controlfield[@tag="007"]', 2) AS `0072`,
    f(metadata, '//controlfield[@tag="007"]', 4) AS `0074`,
    f(metadata, '//controlfield[@tag="007"]', 10 AS `00710`

FROM biblio_metadata LIMIT 1;


SELECT
    ExtractValue(metadata, '//controlfield[@tag="007"]') AS `007`,
    count(*)
FROM biblio_metadata
GROUP BY `007`;


