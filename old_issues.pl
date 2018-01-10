#!/usr/bin/perl -w

use Modern::Perl;
use YAML::Syck qw( LoadFile );
use Getopt::Long::Descriptive;
use DBI;
use Data::Dumper;
use DateTime::Format::Builder;
use Template;

# +------------------+-------------+------+-----+-------------------+-----------------------------+
# | Field            | Type        | Null | Key | Default           | Extra                       |
# +------------------+-------------+------+-----+-------------------+-----------------------------+
# | issue_id         | int(11)     | NO   | PRI | NULL              |                             |
# | borrowernumber   | int(11)     | YES  | MUL | NULL              |                             |
# | itemnumber       | int(11)     | YES  | MUL | NULL              |                             |
# | date_due         | datetime    | YES  |     | NULL              |                             |
# | branchcode       | varchar(10) | YES  | MUL | NULL              |                             |
# | returndate       | datetime    | YES  |     | NULL              |                             |
# | lastreneweddate  | datetime    | YES  |     | NULL              |                             |
# | renewals         | tinyint(4)  | YES  |     | NULL              |                             |
# | auto_renew       | tinyint(1)  | YES  |     | 0                 |                             |
# | auto_renew_error | varchar(32) | YES  |     | NULL              |                             |
# | timestamp        | timestamp   | NO   |     | CURRENT_TIMESTAMP | on update CURRENT_TIMESTAMP |
# | issuedate        | datetime    | YES  |     | NULL              |                             |
# | onsite_checkout  | int(1)      | NO   |     | 0                 |                             |
# | note             | mediumtext  | YES  |     | NULL              |                             |
# | notedate         | datetime    | YES  |     | NULL              |                             |
# +------------------+-------------+------+-----+-------------------+-----------------------------+


my ($opt, $usage) = describe_options(
    '%c %o <some-arg>',
    [ 'configdir=s',  'config directory' , { required => 1 } ],

           [],
    [ 'verbose|v',  "print extra stuff"            ],
    [ 'branchcode|b=s',  "Default branchcode", { required => 1} ],
           [ 'help',       "print usage message and exit", { shortcircuit => 1 } ],
         );

print $usage->text if ($opt->help);

my $config;
if ( -f ($opt->configdir . '/config.yaml') ) {
    $config = LoadFile( $opt->configdir . '/config.yaml' );
}

our $date_parser = DateTime::Format::Builder->new()->parser( regex => qr/^(\d{4})(\d\d)(\d\d)$/,
                                                            params => [qw(year month day)] );
our $dbh = DBI->connect( $config->{'db_dsn'},
                        $config->{'db_user'},
                        $config->{'db_pass'},
                        { RaiseError => 1, AutoCommit => 1 } );

our $time_parser = DateTime::Format::Builder->new()->parser( regex => qr/^(\d{4})(\d\d)(\d\d) (\d+):(\d+)(?::(\d+))?$/,
							     params => [qw(year month day hour minute second)],
							     postprocess => sub {
								 my ($date, $p) = @_;
								 unless (defined $p->{second}) {
								     $p->{second} = 0;
								 }
								 return 1;
							     }
    );
sub dp {
    my $ds = shift;
    if (!defined($ds) || $ds =~ /^ *$/) {
        return undef;
    }
    return $date_parser->parse_datetime($ds);
}

sub ds {
    my $d = shift;
    $d = dp($d);
    if (defined($d)) {
       return $dbh->quote($d->strftime( '%F' ));
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
    }
    return $time_parser->parse_datetime($ds);
}

sub ts {
    my $d = shift;
    my $t = shift;
    $d = tp($d, $t);
    if (defined($d)) {
       return $dbh->quote($d->strftime( '%F %T' ));
    } else {
       return "NULL";
    }
}
my $branchcodes;
if ( -f $opt->configdir . '/branchcodes.yaml' ) {
    $branchcodes = LoadFile( $opt->configdir . '/branchcodes.yaml' );
}

# Configure Template Toolkit
my $ttconfig = {
    INCLUDE_PATH => '',
    ENCODING => 'utf8'
};
# create Template object
my $tt2 = Template->new( $ttconfig ) || die Template->error(), "\n";

my $sth = $dbh->prepare( 'SELECT TransactionsSaved.*, BorrowerBarCodes.BarCode, Borrowers.RegDate AS DateEnrolled, Borrowers.FirstName, Borrowers.LastName, CA_CATALOG.TITLE_NO FROM TransactionsSaved JOIN CA_CATALOG ON IdCat = CA_CATALOG_ID LEFT OUTER JOIN Borrowers USING (IdBorrower) LEFT OUTER JOIN BorrowerBarCodes USING (IdBorrower) ' );

my $ret = $sth->execute();
die "Failed to execute sql query." unless $ret;

while (my $row = $sth->fetchrow_hashref()) {
    
    my $params = {
	title_no => $dbh->quote($row->{TITLE_NO}),
	cardnumber => $dbh->quote($row->{BarCode}),
	callnumber => $dbh->quote($row->{Location_Marc}),
	returndate => ds($row->{RegDate}),
	timestamp  => ts($row->{RegDate}, $row->{RegTime}),
	branchcode => $dbh->quote($opt->branchcode),
	surname =>    $dbh->quote($row->{LastName}),
	firstname =>  $dbh->quote($row->{FirstName}),
	dateenrolled => ds( $row->{DateEnrolled} )
    };

    $tt2->process( 'old_issues.tt', $params, \*STDOUT, {binmode => ':utf8'}) || die $tt2->error();
}

