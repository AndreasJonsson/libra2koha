#!/usr/bin/env perl 
 
# Copyright 2015 Magnus Enger Libriotech
 
=head1 NAME

borrowers.pl - Extract information about borrowers and format for import into Koha.

=head1 SYNOPSIS

 records.pl -v --config /home/my/library/

=cut

use DBI;
use Getopt::Long;
use YAML::Syck qw( LoadFile );
use Term::ProgressBar;
use Template;
use DateTime;
use Pod::Usage;
use Modern::Perl;
use Data::Dumper;
use Email::Valid;

$|=1; # Flush output

# Get options
my ( $config_dir, $limit, $every, $verbose, $debug ) = get_options();

$limit = 130889 if $limit == 0; # FIXME Get this from the database
my $progress = Term::ProgressBar->new( $limit );

=head1 CONFIG FILES

Config files should be kept in one directory and pointed to by the -c or
--config option.

=head2 config.yaml

The main configuration file. Contains things like username and password for
connecting to the database.

See config-sample.yaml for an example.

=cut

my $config;
if ( -f $config_dir . '/config.yaml' ) {
    $config = LoadFile( $config_dir . '/config.yaml' );
}
my $output_file = $config->{'output_marcxml'};

=head2 branchcodes.yaml

Mapping from Branches.IdBRanchCode in Libra to branchcodes in Koha. Have a look
at Branches.txt in the exported data to get an idea of what should go into this
mapping.

=cut

my $branchcodes;
if ( -f $config_dir . '/branchcodes.yaml' ) {
    $branchcodes = LoadFile( $config_dir . '/branchcodes.yaml' );
}

=head2 patroncategories.yaml

Mapping from Borrowers.IdBorrowerCategory in Libra to patron categories in Koha.
Have a look at BorrowerCategories.txt in the exported data to get an idea of
what should go into this mapping.

=cut

my $patroncategories;
if ( -f $config_dir . '/patroncategories.yaml' ) {
    $patroncategories = LoadFile( $config_dir . '/patroncategories.yaml' );
}

# Set up the database connection
my $dbh = DBI->connect( $config->{'db_dsn'}, $config->{'db_user'}, $config->{'db_pass'}, { RaiseError => 1, AutoCommit => 1 } );

# Query for selecting all borrowers, with relevant data
my $sth = $dbh->prepare("
    SELECT Borrowers.*, BarCodes.BarCode, BorrowerRegId.RegId
    FROM (Borrowers LEFT OUTER JOIN BarCodes USING (IdBorrower)) LEFT OUTER JOIN BorrowerRegId USING (IdBorrower)
");

my $addresses_sth = $dbh->prepare("SELECT * FROM BorrowerAddresses WHERE IdBorrower = ?");
my $phone_sth = $dbh->prepare("SELECT * FROM BorrowerPhoneNumbers WHERE IdBorrower = ?");

=head1 PROCESS BORROWERS

Walk through all borrowers and perform necesarry actions.

=cut

say "Starting borrower iteration" if $verbose;
my $count = 0;

# Configure Template Toolkit
my $ttconfig = {
    INCLUDE_PATH => '', 
    ENCODING => 'utf8'  # ensure correct encoding
};
# create Template object
my $tt2 = Template->new( $ttconfig ) || die Template->error(), "\n";

$sth->execute();
# my $borrowers = $sth->fetchall_arrayref({});
# ITEM: foreach my $b ( @{ $borrowers } ) {

my $auto_count = 1;

while ( my $borrower = $sth->fetchrow_hashref() ) {

    say Dumper $borrower if $debug;

    # Only do every x record
    if ( $every && ( $count % $every != 0 ) ) {
        $count++;
        next RECORD;
    }

    if ( !defined($borrower->{'BarCode'}) || $borrower->{'BarCode'} eq '' ) {
        $borrower->{'BarCode'} = "AUTO$auto_count";
        $auto_count++;
    }

    set_address( $borrower );

    my $isKohaMarked = 0;
    my @messages = ();
    if ($borrower->{'Message'}) {
	$isKohaMarked = $borrower->{'Message'} =~ /\bkoha\b/;
	push @messages, $dbh->quote($borrower->{'Message'});
    }
    if ($borrower->{'Comment'}) {
	$isKohaMarked = $isKohaMarked or $borrower->{'Comment'} =~ /\bkoha\b/;
	push @messages, $dbh->quote($borrower->{'Comment'});
    }
    $borrower->{'messages'} = \@messages;

    # Do transformations
    # Add a branchcode
    $borrower->{'branchcode'} = $branchcodes->{ $borrower->{'IdBranchCode'} };
    # Fix the format of dates
    $borrower->{'dateofbirth'} = _fix_date( $borrower->{'BirthDate'} );
    $borrower->{'dateenrolled'} = _fix_date( $borrower->{'RegDate'} );
    if ($isKohaMarked) {
	$borrower->{'dateexpiry'}   = '"' . DateTime->now->add( 'years' => 1000 )->strftime( '%F' ) . '"';
    } else {
	$borrower->{'dateexpiry'}   = '"' . DateTime->now->subtract( 'days' => 1 )->strftime( '%F' ) . '"';
    }
    # Tranlsate patron categories
    $borrower->{'categorycode'} = $patroncategories->{ $borrower->{'IdBorrowerCategory'} };
    next if ($borrower->{'categorycode'} eq '');

    $borrower->{'userid'} = $borrower->{'BarCode'};
    
    if (defined($borrower->{RegId}) && $borrower->{RegId} ne '') {
	$borrower->{'userid'} = $borrower->{RegId};
    }

    $tt2->process( 'borrowers.tt', $borrower, \*STDOUT,  {binmode => ':utf8'} ) || die $tt2->error();

    if (defined($borrower->{RegId}) && $borrower->{RegId} ne '') {
        $tt2->process( 'borrower_attributes.tt', {  'code' => 'PERSNUMMER',
                                                    'attribute' => $borrower->{RegId}
                       }, \*STDOUT, {binmode => ':utf8'}) || die $tt2->error();
    }

    $count++;
    if ( $limit && $limit == $count ) {
        last;
    }
    $progress->update( $count );

} # end foreach record

$progress->update( $limit );

# say "$count borrowers done";
# say "Did you remember to load data into memory?" if $count == 0;

=head1 SUBROUTINES

Internal subroutines.

=cut

sub _fix_date {

    my ( $d ) = @_;
    if ( $d && length $d == 8 ) {
        $d =~ m/(\d{4})(\d{2})(\d{2})/;
        return "\"$1-$2-$3\"";
    } else {
        return 'NULL';
    }

}

=head1 OPTIONS

=over 4

=item B<-c, --config>

Path to directory that contains config files. See the section on
L</"CONFIG FILES"> above for more details.

=item B<-l, --limit>

Only process the n first somethings.

=item B<-e, --every>

Process every x record. E.g. every 5th record.

=item B<-v --verbose>

More verbose output.

=item B<-d --debug>

Even more verbose output.

=item B<-h, -?, --help>

Prints this help message and exits.

=back
                                                               
=cut
 
sub get_options {
 
    # Options
    my $config_dir  = '';
    my $limit       = 0;
    my $every       = '';
    my $verbose     = '';
    my $debug       = '';
    my $help        = '';
 
    GetOptions (
        'c|config=s'  => \$config_dir,
        'l|limit=i'   => \$limit,
        'e|every=i'   => \$every,
        'v|verbose'   => \$verbose,
        'd|debug'     => \$debug,
        'h|?|help'    => \$help
    );
 
    pod2usage( -exitval => 0 ) if $help;
    pod2usage( -msg => "\nMissing Argument: -c, --config required\n",  -exitval => 1 ) if !$config_dir;
 
    return ( $config_dir, $limit, $every, $verbose, $debug );
 
}

## Internal subroutines.

# If these are needed elswhere they should be moved to some kind of include.

# Takes: YYYYMMDD
# Returns: YYYY-MM-DD

sub fix_date {

    my ( $d ) = @_;
    my $year  = substr $d, 0, 4;
    my $month = substr $d, 4, 2;
    my $day   = substr $d, 6, 2;
    return "$year-$month-$day";

}


#
# Fill out converted address fields.
sub set_address {
    my $borrower = shift;

    $addresses_sth->execute( $borrower->{IdBorrower} );

    my $n_addr = 0;
    my $pre;

    while (my $addr = $addresses_sth->fetchrow_hashref()) {
        if ($n_addr == 0) {
            $pre = '';
        } elsif ($n_addr == 1) {
            $pre = 'B_';
        } else {
            print(STDERR ("Borrower has more than 2 addresses: " . $borrower->{IdBorrower} . "\n"));
            last;
        }

        if (defined($addr->{CO}) && $addr->{CO} ne '') {
            if ($n_addr > 0) {
                print(STDERR ("CO field on second address for borrower " . $borrower->{IdBorrower} . "\n"));
            } else {
                $borrower->{contactname} = $addr->{CO};
            }
        }

        $n_addr++;

        if (!defined($addr->{Address1})) {
            $borrower->{"${pre}address"} = '';
            $borrower->{"${pre}streetnumber"} = '';
        } elsif ($addr->{Address1} =~ /^(.*?)[ ]*(\d+(?:(?:[a-zA-Z]+)|(?:,[ ]*\d+tr\.))?)$/) {
            $borrower->{"${pre}address"} = $1;
            $borrower->{"${pre}streetnumber"} = $2;
        } else {
            $borrower->{"${pre}address"} = $addr->{Address1};
            $borrower->{"${pre}streetnumber"} = '';
        }

        $borrower->{"${pre}address2"} = '';
        $borrower->{"${pre}address2"} .= $addr->{Address2} if (defined($addr->{Address2}));
        $borrower->{"${pre}address2"} .= $addr->{Address3} if (defined($addr->{Address3}));

        $borrower->{"${pre}zipcode"} = $addr->{ZipCode} if (defined($addr->{ZipCode}));
        $borrower->{"${pre}country"} = $addr->{Country} if (defined($addr->{Country}));
        $borrower->{"${pre}city"}    = $addr->{City}    if (defined($addr->{City}));
    }

    $phone_sth->execute( $borrower->{IdBorrower} );

    my ($n_phone, $n_email, $n_mob) = (0, 0, 0);

    while (my $phone = $phone_sth->fetchrow_hashref()) {

        next unless defined($phone->{PhoneNumber}) and $phone->{PhoneNumber} ne '';
      RETRY: while (1) {
	  if ($phone->{Type} eq 'E') {
	      if ($n_email == 0) {
		  $pre = '';
	      } elsif ($n_email == 1) {
		  $pre = 'B_';
	      } else {
		  print(STDERR ("Borrower has more than 2 email addresses: " . $borrower->{IdBorrower} . "\n"));
	      }

	      $n_email++;

	      $borrower->{"${pre}email"} = $phone->{PhoneNumber};
	  } elsif ($phone->{Type} eq 'T') {
	      if (Email::Valid->address($phone->{PhoneNumber})) {
		  $phone->{Type} = 'E';
		  next RETRY;
	      }
	      if ($n_phone == 0) {
		  $pre = '';
	      } elsif ($n_phone == 1) {
		  $pre = 'B_';
	      } else {
		  print(STDERR ("Borrower has more than 2 phone numbers: " . $borrower->{IdBorrower} . "\n"));
	      }

	      $n_phone++;

	      $borrower->{"${pre}phone"} = $phone->{PhoneNumber};
	  } elsif ($phone->{Type} eq 'M') {
	      if (Email::Valid->address($phone->{PhoneNumber})) {
		  $phone->{Type} = 'E';
		  next RETRY;
	      }
	      if ($n_mob > 0) {
		  if ($n_phone < 2) {
		      # Make the previous mobile phone number a regular phone number.
		      my $tmpphone = $borrower->{"mobile"};
		      $borrower->{"mobile"} = $phone->{PhoneNumber};
		      $phone->{PhoneNumber} = $tmpphone;
		      $phone->{Type} = 'T';
		  } else {
		      print(STDERR ("Borrower has more than 3 phone numbers: " . $borrower->{IdBorrower} . "\n"));
		      last RETRY;
		  }
	      }
	      $n_mob++;
	      $borrower->{"mobile"} = $phone->{PhoneNumber};
	  } else {
	      print(STDERR ("Borrower has unknown phone number type: '" . $phone->{Type} . "', " . $borrower->{IdBorrower} . "\n"));
	  }
	  last RETRY;
      }
    }
}

=head1 AUTHOR

Magnus Enger, <magnus [at] libriotech.no>

=head1 LICENSE

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut
