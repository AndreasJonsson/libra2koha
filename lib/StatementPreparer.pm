package StatementPreparer;

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw();
@EXPORT_OK   = qw();

use Modern::Perl;
use Carp;
use utf8;

sub new {
    my ($class, %args) = @_;

    return bless {
	dbh => $args{dbh},
	format => $args{format},
	dir => $args{dir}
    };

}

sub prepare {
    my $self = shift;
    my $name = shift;

    for my $d (@{$self->{dir}}, $self->{format}) {
	my $filename = $d . "/${name}.sql";

	next unless -e $filename;

	open SQL, "<:encoding(UTF-8)", $filename  or croak "Failed to open $filename: $!";

	my $sql = join "\n", <SQL>;

	utf8::decode($sql);
	
	my $stmnt =  $self->{dbh}->prepare($sql);

	close SQL;

	return $stmnt;
    }
}

1;
