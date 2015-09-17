use Modern::Perl;

sub get_itemtype {

    # Takes: A MARC record
    # Returns: An appropriate itemtype for the record

    my ( $record ) = @_;

    # Pick out all the codes we need to make our decisions
    my $f000p0  = _get_pos( '000', 0,  $record );
    my $f000p1  = _get_pos( '000', 1,  $record );
    my $f000p6  = _get_pos( '000', 6,  $record );
    my $f000p7  = _get_pos( '000', 7,  $record );
    my $f006p0  = _get_pos( '006', 0,  $record );
    my $f006p4  = _get_pos( '006', 4,  $record );
    my $f006p9  = _get_pos( '006', 9,  $record );
    my $f007p0  = _get_pos( '007', 0,  $record );
    my $f007p1  = _get_pos( '007', 1,  $record );
    my $f007p4  = _get_pos( '007', 4,  $record );
    my $f007p10 = _get_pos( '007', 10, $record );
    my $f008p21 = _get_pos( '008', 21, $record );
    my $f008p24 = _get_pos( '008', 24, $record );
    my $f008p25 = _get_pos( '008', 25, $record );
    my $f008p26 = _get_pos( '008', 26, $record );
    my $f008p27 = _get_pos( '008', 27, $record );
        
    my $itemtype = 'X';

    # Taktila resurser
    # http://www.kb.se/katalogisering/Formathandboken/Bibliografiska-formatet/007/Taktilt-material/
    if ( $f007p0 eq 'f' ) {
        $itemtype = 'PUNKT';

    # Musikalisk resurs eller ljudupptagning 
    # http://www.kb.se/katalogisering/Formathandboken/Bibliografiska-formatet/008/Musikalisk-resurs/
    } elsif ( $f000p6 eq 'c' || $f000p6 eq 'd' ) {
        $itemtype = 'NOTER';

    } elsif ( $f000p6 eq 'j' && $f007p0 eq 's' ) {
        if ( $f007p1 eq 's' ) {
            $itemtype = 'KASSETT';
        } elsif ( $f007p1 eq 'd' && $f007p10 eq 'm' ) {
            $itemtype = 'MUSIKCD';
        } elsif ( $f007p1 eq 'd' && $f007p10 eq 'p' ) {
            $itemtype = 'MUSIKLP';
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
            $itemtype = 'TIDSSKRIFT';
        } elsif ( $f006p4 eq '_' || $f008p21 eq '_' ) {
            $itemtype = "AARSBOK";
        } elsif ( $f008p21 eq 'n' ) {
            $itemtype = "TIDNINGAR";
        }

    # Elektronisk resurs
    # http://www.kb.se/katalogisering/Formathandboken/Bibliografiska-formatet/008/Elektronisk-resurs-/
    } elsif ( $f000p6 eq 'm' || $f006p0 eq 'm' ) {
        if ( $record->field( '500' ) ) {
            foreach my $f500 ( $record->field( '500' ) ) {
                my $f500a = $f500->subfield( 'a' );
                if ( $f500a =~ m/Nintendo DS/ ) {
                    $itemtype = 'DS';
                }
            }
        } elsif ( $f006p9 eq 'g' || $f008p26 eq 'g' ) {
            $itemtype = "TV-SPEL";
        } elsif ( $f008p26 eq 'j' ) {
            $itemtype = "DATABAS";
        } elsif ( $record->field( '500' ) && $record->subfield( '500', 'a' ) ) {
            foreach my $note ( $record->subfield( '500', 'a' ) ) {
                if ( $note =~ m/Spr.kkurs/gi ) {
                    $itemtype = "SPRAK-CD";
                }
            }
        } else {
            $itemtype = "CD-ROM";
        }
        
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
    }

    return $itemtype;

}

sub _get_pos {

    # Takes: A string
    # Returns: the char at the given position

    my ( $field, $pos, $record ) = @_;
    if ( $record->field( $field ) && $record->field( $field )->data() ) {
        my $string = $record->field( $field )->data();
        my @chars = split //, $string;
        return $chars[ $pos ];
    } else {
        return '_';
    }

}

1;
