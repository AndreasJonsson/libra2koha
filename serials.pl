#!/usr/bin/env perl

use Modern::Perl;
use YAML::Syck qw( LoadFile );
use Pod::Usage;
use DBI;
use Dumper::Simple;

=head1 OPTIONS

=over 4

=item B<-c, --config>

Path to directory that contains config files. See the section on
L</"CONFIG FILES"> above for more details.

=item B<-v --verbose>

More verbose output.

=item B<-d --debug>

Even more verbose output.

=item B<-h, -?, --help>

Prints this help message and exits.

=back

=cut

my $config_dir;
my $debug = 0;
my $verbose = 0;

GetOptions (
    'c|config=s'           => \$config_dir,
    'v|verbose'            => \$verbose,
    'd|debug'              => \$debug,
    'h|?|help'             => \$help
    );


pod2usage( -exitval => 0 ) if $help;
pod2usage( -msg => "\nMissing Argument: -c, --config required\n",  -exitval => 1 ) if !$config_dir;
pod2usage( -msg => "\nMissing Argument: -i, --data required\n",  -exitval => 1 ) if !$data_dir;

my $config;
if ( -f $config_dir . '/config.yaml' ) {
    $config = LoadFile( $config_dir . '/config.yaml' );
}

my $dbh = DBI->connect( $config->{'db_dsn'},
                        $config->{'db_user'},
                        $config->{'db_pass'},
                        { RaiseError => 1, AutoCommit => 1 } );

my $sth = $dbh->prepare( 'SELECT * FROM Issues, IdMapWHERE Issues.IdCat=IdMap.original' );
my $serialitems_sth = $dbh->prepare( 'SELECT * From Items, BarCodes WHERE BarCodes.IdItem = Items.IdItem AND Item.IdIssue = ?' );

$ret = $sth->execute();
die "Failed to query issues!" unless (defined($ret));

while (my $row = $sth->fetchrow_hashref()) {
    say Dumper($row);
}



