#!/usr/bin/env perl

use Modern::Perl;
use Pod::Usage;
use DBI;
use YAML::Syck qw( LoadFile );

=head1 OPTIONS

=over 4

=item B<-i, --idmap>

The idmap file to load the data from.

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


my $idmap;
my $verbose = 0;
my $debug = 0;
my $help = 0;


GetOptions (
    'i|idmap=s'            => \$idmap,
    'c|config=s'           => \$config_dir,
    'v|verbose'            => \$verbose,
    'd|debug'              => \$debug,
    'h|?|help'             => \$help
    );

pod2usage( -exitval => 0 ) if $help;
pod2usage( -msg => "\nMissing Argument: -c, --config required\n",  -exitval => 1 ) if !$config_dir;
pod2usage( -msg => "\nMissing Argument: -i, --idmap required\n",  -exitval => 1 ) if !$idmap;

my $config;
if ( -f $config_dir . '/config.yaml' ) {
    $config = LoadFile( $config_dir . '/config.yaml' );
}


my $dbh = DBI->connect( $config->{'db_dsn'} . ';mysql_local_infile=1',
                        $config->{'db_user'},
                        $config->{'db_pass'},
                        { RaiseError => 1, AutoCommit => 1 } );

$dbh->do( <<"EOF" );
CREATE TABLE `IdMap` (
  original BIGINT UNIQUE NOT NULL,
  biblioitem BIGINT UNIQUE NOT NULL,
  PRIMARY KEY(`original`),
  KEY(`biblioitem`)
) ENGINE=MEMORY;
LOAD DATA LOCAL INFILE '$idmap' INTO TABLE `IdMap` CHARACTER SET utf8 FIELDS TERMINATED BY '|' LINES TERMINATED BY '\n';
EOF
