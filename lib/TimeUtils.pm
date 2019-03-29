package TimeUtils;

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(ds ts dp init_time_utils);
@EXPORT_OK   = qw();

use Modern::Perl;
use DateTime;
use DateTime::Format::Builder;

our $date_parser = DateTime::Format::Builder->new()->parser( regex => qr/^(\d{4})-(\d\d)-(\d\d)/,
                                                            params => [qw(year month day)] );

our $time_parser = DateTime::Format::Builder->new()->parser( regex => qr/^(\d{4})-(\d\d)-(\d\d) (\d+):(\d+)(?::(\d+))?$/,
							     params => [qw(year month day hour minute second)],
							     postprocess => sub {
								 my ($date, $p) = @_;
								 unless (defined $p->{second}) {
								     $p->{second} = 0;
								 }
								 return 1;
							     }
    );

my $quote;

sub init_time_utils {
    $quote = shift;
}

sub dp {
    my $ds = shift;
    if (!defined($ds) || $ds =~ /^ *$/) {
        return undef;
    }
    return $date_parser->parse_datetime($ds);
}

sub ds {
    my $d = shift;
    if (defined($d) && !($d =~ /^(00|19)00-00-00/)) {
	$d = dp($d);
       return $quote->($d->strftime( '%F' ));
    } else {
       return "NULL";
    }
}

sub tp {
    my $ds = shift;
    my $ts = shift;
    if (!defined($ds) || $ds =~ /^ *$/) {
        return undef;
    }
    if (defined($ts) && !$ds =~ /^ *$/) {
	$ds .= " $ts";
    } else {
	$ds .= ' 0:00:00';
    }
    return $time_parser->parse_datetime($ds);
}

sub ts {
    my $d = shift;
    my $t = shift;
    $d = tp($d, $t);
    if (defined($d)) {
       return $quote->($d->strftime( '%F %T' ));
    } else {
       return "NULL";
    }
}


1;
