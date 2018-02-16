package StatementPreparer;

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw();
@EXPORT_OK   = qw();

use Modern::Perl;
use Carp;

sub new {
    my ($class, %args) = @_;

    return bless {
	dbh => $args{dbh},
	format => $args{format}
    };

}

sub prepare {
    my $self = shift;
    my $name = shift;

    my $filename = $self->{format} . "/${name}.sql";

    open SQL, "<:utf8", $filename  or croak "Failed to open $filename: $!";

    my $sql = join "\n", <SQL>;

    my $stmnt =  $self->{dbh}->prepare($sql);

    close SQL;

    return $stmnt;
}

1;
