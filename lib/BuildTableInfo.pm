package BuildTableInfo;

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(build_table_info);
@EXPORT_OK   = qw();

use strict;
use Modern::Perl;
use Data::Dumper;
use File::BOM;
use Text::CSV;

use Getopt::Long::Descriptive;

sub create_file_hash {
    my $dir = shift;
    my $pattern = shift;
    my $dh;
    opendir($dh, $dir)  or die ($dir . ": $!");
    my %hash = ();
    while (my $file = readdir $dh) {
	if ($file =~ /$pattern/) {
	    $hash{$1} = {
		'filename' => $file
	    };
	}
    }
    close $dh;
    return \%hash;
}

sub build_table_info {
    my $opt = shift;
	
    
    my $csvfiles  = create_file_hash($opt->dir, '(.*)' . $opt->ext . '$');
    my $specfiles = create_file_hash($opt->spec, '(.*)spec.txt$');

    my @missingspecs = ();
    my @missingcsvs = ();

    for (keys %$csvfiles) {
	$csvfiles->{$_}->{missingspec} = !defined($specfiles->{$_});
	if ($csvfiles->{$_}->{missingspec}) {
	    push @missingspecs, $_;
	} 
	my $base = $_;
	my $fh;
	my $csvfile = $opt->dir . "/" . $csvfiles->{$base}->{filename};
	open $fh, ("<:encoding(" . $opt->encoding . "):via(File::BOM)"), $csvfile or die ($csvfile . ": $!");
	my $csv = Text::CSV->new({
	    quote_char => $opt->quote,
	    sep_char => $opt->columndelimiter,
	    eol => $opt->rowdelimiter,
	    escape_char => $opt->escape
				 });


	my $columns = $csv->getline( $fh );

	my %columns = ();
	my $i = 0;
	for my $c (@$columns) {
	    $columns{$c} = {
		'position' => $i,
	    };
	    $i++;
	}
	$csvfiles->{$base}->{columns} = \%columns;
	$csvfiles->{$base}->{columnlist} = $columns;
	$csvfiles->{$base}->{missingspecs} = [];
	close $fh;
	if (!$csvfiles->{$_}->{missingspec}) {
	    my $specfile = $opt->spec . "/" . $specfiles->{$base}->{filename};
	    open $fh, ("<:encoding(" . $opt->specencoding . ")"), $specfile;
	    my %columns_spec = ();
	    $i = 0;
	    while (<$fh>) {
		s/\r\n//g;
		my @col = split "\t";
		my $name = $col[0];
		my $type = $col[1];
		my $typeextra = $col[2];
		$columns_spec{$name} = {
		    'type' => $type,
		    'typeextra' => $typeextra,
		    'position' => $i
		};
		$specfiles->{$base}->{columns} = \%columns_spec;
		$i++;
	    }
	    $specfiles->{$base}->{missingcsvs} = [];

	    foreach my $c (keys %{$csvfiles->{$base}->{columns}}) {
		if (!defined($specfiles->{$base}->{columns}->{$c})) {
		    push @{$csvfiles->{$base}->{missingspecs}}, $c;
		}
	    }

	    foreach my $c (keys %{$specfiles->{$base}->{columns}}) {
		if (!defined($csvfiles->{$base}->{columns}->{$c})) {
		    push @{$specfiles->{$base}->{missingcsvs}}, $c;
		}
	    }
	}
    }

    for (keys %$specfiles) {
	if (!defined($csvfiles->{$_})) {
	    push @missingcsvs, $_;
	}
    }
    return ($csvfiles, $specfiles, \@missingcsvs, \@missingspecs);
}



1;
