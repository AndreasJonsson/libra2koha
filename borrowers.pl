#!/usr/bin/env perl
 
# Copyright 2015 Magnus Enger Libriotech
 
=head1 NAME

borrowers.pl - Extract information about borrowers and format for import into Koha.

=head1 SYNOPSIS

 records.pl -v --g /home/my/library/

=cut

use DBI;
use Getopt::Long;
use YAML::Syck qw( LoadFile );
use Term::ProgressBar;
use Template;
use Pod::Usage;
use Modern::Perl;
use Data::Dumper;
use Email::Valid;
use StatementPreparer;
use TimeUtils qw(ds ts init_time_utils);
use Koha::AuthUtils qw(hash_password);
use utf8;

sub fix_charcode {
    my $s = shift;
    utf8::decode($s);
    return $s;
}

$|=1; # Flush output


# Get options
my ( $config_dir, $limit, $every, $format, $verbose, $debug ) = get_options();


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
my $preparer = new StatementPreparer(format => $format, dbh => $dbh);
init_time_utils(sub { return $dbh->quote(shift); });

if (!defined($limit) || $limit == 0) {
    my $count_sth = $preparer->prepare('count_borrowers');
    $count_sth->execute() or die "Failed to count borrowers!";
    $limit = $count_sth->fetchrow_arrayref()->[0];
}
print STDERR "Limit: $limit\n";
my $progress = Term::ProgressBar->new( $limit );


# Query for selecting all borrowers, with relevant data
my $sth = $preparer->prepare('select_borrower_info');

my $blocked_sth; # = $dbh->prepare('SELECT * FROM BorrowerBlocked WHERE IdBorrower = ?');

my $addresses_sth = $preparer->prepare('select_borrower_addresses');

my $phone_sth = $preparer->prepare('select_borrower_phone');

my $message_sth;
if ($format eq 'bookit') {
    $message_sth = $dbh->prepare('SELECT MODIFY_DATETIME AS date, MESSAGE AS message FROM CI_BORR_MESSAGE WHERE CI_BORR_ID = ?');
}

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
binmode( STDOUT, ":utf8" );
# create Template object
my $tt2 = Template->new( $ttconfig ) || die Template->error(), "\n";

$sth->execute();
# my $borrowers = $sth->fetchall_arrayref({});
# ITEM: foreach my $b ( @{ $borrowers } ) {

my $auto_count = 1;

print <<EOF;

DROP TABLE IF EXISTS import_table_borrower_idmap;
CREATE TABLE import_table_borrower_idmap (
  `source_id` int PRIMARY KEY NOT NULL,
  `target_id` int UNIQUE KEY NOT NULL
);

EOF

RECORD: while ( my $borrower = $sth->fetchrow_hashref() ) {

    say Dumper $borrower if $debug;

    # Only do every x record
    if ( $every && ( $count % $every != 0 ) ) {
        $count++;
        next RECORD;
    }

    my @barcodes = ();

    if ( !defined($borrower->{'BarCode'}) || $borrower->{'BarCode'} eq '' ) {
        $borrower->{'cardnumber_str'} = "NULL";
    } else {
	@barcodes = split ';', $borrower->{'BarCode'};
	$borrower->{'cardnumber_str'} = $dbh->quote(shift @barcodes);
    }

    set_address( $borrower );
    #set_debarments( $borrower );
    $borrower->{debarredcomment} = 'NULL';
    $borrower->{debarred} = 'NULL';

    my $isKohaMarked = 0;
    my @messages = ();
    # if ($borrower->{'Message'}) {
    # $isKohaMarked = $borrower->{'Message'} =~ /\bkoha\b/i;
    # push @messages, { text => $dbh->quote($borrower->{'Message'})};
    #}
    #if ($borrower->{'Comment'}) {
    #	$isKohaMarked = $isKohaMarked or $borrower->{'Comment'} =~ /\bkoha\b/i;
    #	push @messages, { text => $dbh->quote($borrower->{'Comment'}) };
    #}

    if ($format eq 'bookit') {
	$message_sth->execute($borrower->{'IdBorrower'});
	while (my $row = $message_sth->fetchrow_hashref()) {
	    push @messages, { text => $dbh->quote(fix_charcode($row->{message})), date => ds($row->{date}) };
	}
    }

    $borrower->{'messages'} = \@messages;

    # Do transformations
    # Add a branchcode
    $borrower->{'branchcode'} = defined($borrower->{'IdBranchCode'}) ? $branchcodes->{ $borrower->{'IdBranchCode'} } : $branchcodes->{ '10000' };
    next RECORD if (!defined($borrower->{'branchcode'}) or $borrower->{'branchcode'} eq '');
    _quoten(\$borrower->{'branchcode'});
    # Fix the format of dates
    $borrower->{'dateofbirth'} = ds($borrower->{'BirthDate'});
    $borrower->{'dateenrolled'} = ds($borrower->{'RegDate'});
    if ($borrower->{'Expires'}) {
	$borrower->{'dateexpiry'} = "'" . $borrower->{'Expires'} . "'";
    } else {
	$borrower->{'dateexpiry'} = "'" . DateTime->now->add( 'years' => 3 )->strftime( '%F' ) . "'";
    }
    #if ($isKohaMarked) {
    # $borrower->{'dateexpiry'}   = '"' . DateTime->now->add( 'years' => 1000 )->strftime( '%F' ) . '"';
    #} else {
    #$borrower->{'dateexpiry'}   = '"' . DateTime->now->subtract( 'days' => 1 )->strftime( '%F' ) . '"';
    #}
    #if (!defined($patroncategories->{ $borrower->{'IdBorrowerCategory'} })) {
    #print STDERR "IdBorrowerCategory not defined:\n";
    #print STDERR Dumper( $borrower );
    #}
    $borrower->{'categorycode'} = $patroncategories->{ $borrower->{'IdBorrowerCategory'} };
    next if (!defined($borrower->{'categorycode'}) or $borrower->{'categorycode'} eq '');
    _quoten(\$borrower->{'categorycode'});

    $borrower->{'userid_str'} = 'NULL';

    if (defined($borrower->{'BarCode'}) && $borrower->{'BarCode'} ne '') {
	$borrower->{'userid_str'} = $borrower->{'cardnumber_str'};
    } 
    if (defined($borrower->{RegId}) && $borrower->{RegId} ne '') {
	$borrower->{'userid_str'} = $dbh->quote($borrower->{RegId});
    }

    if (defined($borrower->{'FullName'})) {
	my $s = $borrower->{'FullName'};
	my $i = index $s, ',';
	if (!defined($borrower->{'FirstName'}) && $i >= 0) {
	    $borrower->{'FirstName'} = substr($s, $i + 1);
	}
	if (!defined($borrower->{'LastName'})) {
	    if ($i >= 0) {
		$borrower->{'LastName'} = substr($s, 0, $i);
		$borrower->{'LastName'} =~ s/^(\s*)//s;
	    } else {
		$borrower->{'LastName'} = $borrower->{'FullName'};
	    }
	}
    }

    _quote(\$borrower->{'FirstName'});
    _quote(\$borrower->{'LastName'});

    if (defined($borrower->{'Password'})) {
	$borrower->{'Password'} = hash_password($borrower->{'Password'});
    }
    _quote(\$borrower->{'Password'});

    $tt2->process( 'borrowers.tt', $borrower, \*STDOUT,  {binmode => ':utf8'} ) || die $tt2->error();

    if (defined($borrower->{RegId}) && $borrower->{RegId} ne '') {
        $tt2->process( 'borrower_attributes.tt', {  'code' => 'PERSNUMMER',
                                                    'attribute' => $borrower->{RegId}
                       }, \*STDOUT, {binmode => ':utf8'}) || die $tt2->error();
    }
    while (scalar(@barcodes) > 0) {
        $tt2->process( 'borrower_attributes.tt', {  'code' => 'EXTRA_CARD',
                                                    'attribute' => shift @barcodes
                       }, \*STDOUT, {binmode => ':utf8'}) || die $tt2->error();
    }

    $count++;
    #if ( $limit && $limit == $count ) {
    #last;
    #}
    $progress->update( $count );

} # end foreach record

#print <<EOF;
#CREATE TEMPORARY TABLE k_borrower_message_preferences_existing (borrowernumber INT(11) PRIMARY KEY NOT NULL);
#START TRANSACTION;
#INSERT INTO k_borrower_message_preferences_existing
#SELECT borrowernumber FROM borrower_message_preferences WHERE message_attribute_id=2 AND borrowernumber IS NOT NULL;

#INSERT INTO borrower_message_preferences (borrowernumber, categorycode, message_attribute_id, days_in_advance, wants_digest)
#SELECT borrowernumber, NULL, 2, 3, 0 FROM borrowers WHERE (SELECT count(*) = 0 FROM k_borrower_message_preferences_existing AS e WHERE e.borrowernumber=borrowers.borrowernumber);
#COMMIT;

#DELETE FROM k_borrower_message_preferences_existing;
#START TRANSACTION;
#INSERT INTO k_borrower_message_preferences_existing
#SELECT borrower_message_preference_id FROM borrower_message_transport_preferences;

#INSERT INTO borrower_message_transport_preferences (borrower_message_preference_id, message_transport_type)
#SELECT borrower_message_preference_id, 'email' FROM borrower_message_preferences WHERE (SELECT count(*) = 0 FROM k_borrower_message_preferences_existing AS e WHERE e.borrowernumber=borrower_message_preferences.borrower_message_preference_id);

#COMMIT;

#EOF


$progress->update( $limit );

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
    my $format      = 'libra';
 
    GetOptions (
        'c|config=s'  => \$config_dir,
        'l|limit=i'   => \$limit,
        'e|every=i'   => \$every,
	'F|format=s'  => \$format,
        'v|verbose'   => \$verbose,
        'd|debug'     => \$debug,
        'h|?|help'    => \$help
    );
 
    pod2usage( -exitval => 0 ) if $help;
    pod2usage( -msg => "\nMissing Argument: -c, --config required\n",  -exitval => 1 ) if !$config_dir;
 
    return ( $config_dir, $limit, $every, $format, $verbose, $debug );
 
}

sub _quote {
    my $s = shift;

    if (defined($$s)) {
	$$s = $dbh->quote($$s);
    } else {
	$$s = 'NULL';
    }
}

sub _quoten {
    my $s = shift;

    if (defined($$s)) {
	$$s = $dbh->quote($$s);
    } else {
	$$s = "''";
    }
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

	my @lines = ();

        if (defined($addr->{CO}) && $addr->{CO} ne '') {
            if ($n_addr > 1) {
                print(STDERR ("CO field on third address for borrower " . $borrower->{IdBorrower} . "\n"));
            } else {
                push @lines, ('c/o ' . clean_control($addr->{CO}));
            }
        }

        $n_addr++;


        if (!defined($addr->{Address1})) {
            $borrower->{"${pre}address"} = '';
            $borrower->{"${pre}streetnumber"} = '';
        } elsif ($addr->{Address1} =~ /^(.*?)[ ]*(\d+(?:(?:[a-zA-Z]+)|(?:,[ ]*\d+tr\.))?)$/) {
	    push @lines, clean_control($addr->{Address1});
            $borrower->{"${pre}streetnumber"} = clean_control($2);
        } else {
	    push @lines, clean_control($addr->{Address1});
            $borrower->{"${pre}streetnumber"} = '';
        }

	push @lines, clean_control($addr->{Address2}) if (defined($addr->{Address2}) && !($addr->{Address2} =~ /^ *$/));
	push @lines, clean_control($addr->{Address3}) if (defined($addr->{Address3}) && !($addr->{Address3} =~ /^ *$/));

	$borrower->{"${pre}address"} = shift @lines;
        $borrower->{"${pre}address2"} = join ', ', @lines;

        $borrower->{"${pre}zipcode"} = clean_control($addr->{ZipCode}) if (defined($addr->{ZipCode}));
        $borrower->{"${pre}country"} = clean_control($addr->{Country}) if (defined($addr->{Country}));
        $borrower->{"${pre}city"}    = clean_control($addr->{City})    if (defined($addr->{City}));
    }


    _quoten(\$borrower->{"address"});
    _quote(\$borrower->{"address2"});
    _quote(\$borrower->{"country"});
    _quote(\$borrower->{"zipcode"});
    _quote(\$borrower->{"streetnumber"});
    _quoten(\$borrower->{"city"});
    _quote(\$borrower->{"B_address"});
    _quote(\$borrower->{"B_address2"});
    _quote(\$borrower->{"B_country"});
    _quote(\$borrower->{"B_zipcode"});
    _quote(\$borrower->{"B_city"});
    _quote(\$borrower->{"B_streetnumber"});

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

	      $borrower->{"${pre}email"} = clean_control($phone->{PhoneNumber});
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

	      $borrower->{"${pre}phone"} = clean_control($phone->{PhoneNumber});
	  } elsif ($phone->{Type} eq 'M') {
	      if (Email::Valid->address($phone->{PhoneNumber})) {
		  $phone->{Type} = 'E';
		  next RETRY;
	      }
	      if ($n_mob > 0) {
		  if ($n_phone < 2) {
		      # Make the previous mobile phone number a regular phone number.
		      my $tmpphone = $borrower->{"mobile"};
		      $borrower->{"mobile"} = clean_control($phone->{PhoneNumber});
		      $phone->{PhoneNumber} = $tmpphone;
		      $phone->{Type} = 'T';
		  } else {
		      print(STDERR ("Borrower has more than 3 phone numbers: " . $borrower->{IdBorrower} . "\n"));
		      last RETRY;
		  }
	      }
	      $n_mob++;
	      $borrower->{"mobile"} = clean_control($phone->{PhoneNumber});
	  } else {
	      print(STDERR ("Borrower has unknown phone number type: '" . $phone->{Type} . "', " . $borrower->{IdBorrower} . "\n"));
	  }
	  last RETRY;
      }
    }
    _quote(\$borrower->{phone});
    _quote(\$borrower->{B_phone});
    _quote(\$borrower->{email});
    _quote(\$borrower->{B_email});
    _quote(\$borrower->{mobile});

}

sub set_debarments {
    my $borrower = shift;

    $blocked_sth->execute( $borrower->{IdBorrower} );
    my @debarments = ();

    while (my $blocked = $blocked_sth->fetchrow_hashref()) {
	my $debarment = {
	    expiration_date => $blocked->{BlockedUntil},
	    expiration => ds($blocked->{BlockedUntil}),
	    type => "'MANUAL'",
	    comment => $blocked->{Reason},
	    created => ts($blocked->{RegDate}, $blocked->{RegTime}),
	    debarred => ds($blocked->{RegDate}),
	    updated => ts($blocked->{UpdatedDate})
	};
	_quote(\$debarment->{comment});
	push @debarments, $debarment;
    }

    if (scalar(@debarments) > 0) {
	$borrower->{debarments} = \@debarments;
	my $d = $debarments[0];
	$borrower->{debarredcomment} = join "\n", map { $_->{comment} } @debarments;
	my $max;
	my $max_ds;
	for my $d (@debarments) {
	    if (!defined($max)) {
		$max = $d->{expiration_date};
		$max_ds = $d->{expiration};
	    } else {
		if (DateTime->compare($max, $d->{expiration_date}) < 0) {
		    $max = $d->{expiration_date};
		    $max_ds = $d->{expiration};
		}
	    }
	}
	if (defined($max)) {
	    $borrower->{debarred} = $max_ds;
	} else {
	    $borrower->{debarred} = ds('99991231');
	}
    } else {
	$borrower->{debarredcomment} = 'NULL';
	$borrower->{debarred} = 'NULL';
    }
}

sub clean_control {
    my $s = shift;

    $s =~ s/[[:cntrl:]]//g;
    
    return $s;
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
