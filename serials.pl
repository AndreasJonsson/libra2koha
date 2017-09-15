#!/usr/bin/env perl

use Modern::Perl;
use YAML::Syck qw( LoadFile );
use Pod::Usage;
use DBI;
use Getopt::Long;
use Data::Dumper;
use DateTime::Format::Builder;
use Template;

=head1 OPTIONS

=over 4

=item B<-c, --config>

Path to directory that contains config files. See the section on
L</"CONFIG FILES"> above for more details.

=item B<-o, --outputdir>

Directory where the resulting sql files will be written.

=item B<-v --verbose>

More verbose output.

=item B<-d --debug>

Even more verbose output.

=item B<-h, -?, --help>

Prints this help message and exits.

=back

=cut

my $config_dir;
my $output_dir;
my $debug = 0;
my $verbose = 0;
my $help = 0;


GetOptions (
    'c|config=s'           => \$config_dir,
    'o|outputdir=s'        => \$output_dir,
    'v|verbose'            => \$verbose,
    'd|debug'              => \$debug,
    'h|?|help'             => \$help
    );


pod2usage( -exitval => 0 ) if $help;
pod2usage( -msg => "\nMissing Argument: -c, --config required\n",  -exitval => 1 ) if !$config_dir;
pod2usage( -msg => "\nMissing Argument: -o, --outputdir required\n",  -exitval => 1 ) if !$output_dir;

say "config dir: $config_dir";
my $config;
if ( -f ($config_dir . '/config.yaml') ) {
       say "loading config";
    $config = LoadFile( $config_dir . '/config.yaml' );
}

our $dbh = DBI->connect( $config->{'db_dsn'},
                        $config->{'db_user'},
                        $config->{'db_pass'},
                        { RaiseError => 1, AutoCommit => 1 } );

# Configure Template Toolkit
my $ttconfig = {
    INCLUDE_PATH => '', 
    ENCODING => 'utf8'
};
# create Template object
my $tt2 = Template->new( $ttconfig ) || die Template->error(), "\n";

my $sth = $dbh->prepare( 'SELECT Issues.*, ISBN_ISSN, TITLE_NO FROM Issues JOIN CA_CATALOG ON CA_CATALOG_ID=IdCat ORDER BY IdCat' );
my $serialitems_sth = $dbh->prepare( 'SELECT IdItem, BarCode  From Items JOIN ItemBarCodes USING(IdItem) WHERE IdIssue = ?' );

# CONCAT(LCASE(REPLACE(ExtractValue(metadata, '//controlfield[\@tag=\"003\"]'), '-', '')), ExtractValue(metadata, '//controlfield[\@tag=\"001\"]'))

our $date_parser = DateTime::Format::Builder->new()->parser( regex => qr/^(\d{4})(\d\d)(\d\d)$/,
                                                            params => [qw(year month day)] );
our $subscription_id = 1;

sub dp {
    my $ds = shift;
    if (!defined($ds) || $ds eq '') {
        return undef;
    }
    return $date_parser->parse_datetime($ds);
}

sub ds {
    my $d = shift;
    if (defined($d)) {
       return $dbh->quote($d->strftime( '%F' ));
    } else {
       return "NULL";
    }
}

my $ret = $sth->execute();
die "Failed to query serials!" unless (defined($ret));

open SERIALS, ">:encoding(UTF-8)", "$output_dir/serials.sql" or die "Failed to open serials.sql for writing: $!";

my $prev_biblio = -1;

while (my $row = $sth->fetchrow_hashref()) {
    #say Dumper($row);
    next unless defined($row->{Name});
    my $serialseq = $dbh->quote($row->{Name});
    my $serialseq_x = $dbh->quote($row->{IssueYear});
    my $serialseq_y = 0;
    if ($serialseq =~ m/ N[ro]\.? *(\d+)$/) {
        $serialseq_y = $1;
    }

    my $planneddate = dp($row->{DateArrival});
    my $publisheddate = dp($row->{ExpectedDateArrival});
    my $status = 0;
    my $biblionumber = $row->{biblioitem};
    my $biblionumber_str = $dbh->quote($biblionumber);

    if (!defined($planneddate)) {
        $status = 1; # expected
    } elsif (defined($publisheddate) && $publisheddate < $planneddate) {
        $status = 3; # late
    } else {
        $status = 2; # arrived
    }

    my $planneddate_str = ds($planneddate);
    my $publisheddate_str = ds($publisheddate);

    my $tt = {
	serialseq    => $serialseq,
	serialseq_x  => $serialseq_x,
	serialseq_y  => $serialseq_y,
	status       => $status,
	planneddate_str => $planneddate_str,
	publisheddate_str => $publisheddate_str,
        issn         => $dbh->quote($row->{ISBN_ISSN}),
	titleno      => $dbh->quote($row->{TITLE_NO}),
	barcodes     => []
    };

    $ret = $serialitems_sth->execute( $row->{IdIssue} );
    die "Failed to query serialitems" unless defined($ret);

    while (my $item_row = $serialitems_sth->fetchrow_hashref()) {
        push @{$tt->{barcodes}},  $dbh->quote($item_row->{BarCode}) if $item_row->{BarCode};
    }

    $tt2->process( 'serials.tt', $tt, \*SERIALS,  {binmode => ':utf8' } ) || die $tt2->error();

}

