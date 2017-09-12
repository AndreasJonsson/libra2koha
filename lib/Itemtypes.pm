package Itemtypes;

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(get_itemtype);
@EXPORT_OK   = qw();

use Modern::Perl;
use Marc21Utils;

use Data::Dumper;

sub get_itemtype {

    # Takes: A MARC record
    # Returns: An appropriate itemtype for the record

    our ( $record ) = @_;

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

    if ($main::debug) {
        print STDERR Dumper(\%fieldpositions);
    }

    my $itemtype = 'X';

    sub electronic_resource {
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
    }


    # Taktila resurser
    # http://www.kb.se/katalogisering/Formathandboken/Bibliografiska-formatet/007/Taktilt-material/
    if ( $f007p0 eq 'f' ) {
        $itemtype = 'PUNKT';

    # Musikalisk resurs eller ljudupptagning
    # http://www.kb.se/katalogisering/Formathandboken/Bibliografiska-formatet/008/Musikalisk-resurs/
    } elsif ( $f000p6 eq 'c' || $f000p6 eq 'd' ) {
        $itemtype = 'NOTER';

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
            $itemtype = 'DVD';
        } else {
            $itemtype = 'DVD';
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
        $itemtype = 'DAISY';
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
        $itemtype = electronic_resource();
    } elsif ( $record->subfield( '852', 'c' ) && $record->subfield( '852', 'c' ) =~ m/TV-SPEL.*/ ) {
        $itemtype = "TV-SPEL";

    # Kartografisk resurs
    # http://www.kb.se/katalogisering/Formathandboken/Bibliografiska-formatet/008/Kartografisk-resurs/
    } elsif ( $f000p6 eq 'e' || $f000p6 eq 'f' ) {
        $itemtype = 'KARTA';

    # Daisy
    # http://libra-hjalp.axiell.com/daisy
    } elsif ( $f000p6 eq 'i' && $f007p0 eq 'c' ) {
        $itemtype = 'DAISY';

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


1;
