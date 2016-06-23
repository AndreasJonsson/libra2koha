package Marc21Utils;

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(get_pos);
@EXPORT_OK   = qw();

use Modern::Perl;

sub get_pos {

    # Takes: A string
    # Returns: the char at the given position

    my ( $field, $pos, $record ) = @_;
    my $s = '';
    if ( $record->field( $field ) && $record->field( $field )->data() ) {
        $s = $record->field( $field )->data();
    } elsif ( $field eq '000' ) {
        # Field '000' should't exist, as this code denotes the leader.  But if it does, we let it override the leader.
        $s = $record->leader();
    }

    if ($pos < length($s)) {
        return substr($s, $pos, 1);
    }

    return '_';
}

1;
