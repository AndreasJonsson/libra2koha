package BuildTableInfo;

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(build_table_info);
@EXPORT_OK   = qw();

use strict;
use Modern::Perl;
use Data::Dumper;
use Text::CSV;

use Getopt::Long::Descriptive;

sub create_file_hash {
    my $dir0 = shift;
    my $pattern = shift;
    my $dh;
    my %hash = ();
    for my $dir (split ':', $dir0) {
	opendir($dh, $dir)  or die ($dir . ": $!");
	while (my $file = readdir $dh) {
	    if ($file =~ /$pattern/) {
		$hash{$1} = {
		    'filename' => $file
		};
	    }
	}
	close $dh;
    }
    return \%hash;
}

sub build_table_info {
    my $opt = shift;

    if ($opt->use_bom) {
	use File::BOM;
    }

    
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
	print STDERR "Open csv file: $csvfile\n" if $opt->verbose;
	if ($opt->use_bom) {
	    open $fh, ("<:encoding(" . $opt->encoding . "):via(File::BOM)"), $csvfile or die ($csvfile . ": $!");
	} else {
	    open $fh, ("<:encoding(" . $opt->encoding . ")"), $csvfile or die ($csvfile . ": $!");
	}
	print STDERR "Done open\n" if $opt->verbose;
	my $params ={
	    sep_char => $opt->columndelimiter,
	};
	if (defined($opt->quote) && $opt->quote ne '') {
	    $params->{quote_char} = $opt->quote;
	}
	if (defined($opt->escape) && $opt->escape ne '') {
	    $params->{escape_char} = $opt->escape;
	}
	if ($opt->rowdelimiter) {
	    $params->{eol} = $opt->rowdelimiter;
	}
	my $csv = Text::CSV->new($params);

	my $columns = $csv->getline( $fh );

	if (!defined($columns)) {
	    print STDERR "Failed to read header line of '$csvfile'\n";
	} elsif (scalar(@$columns) == 0) {
	    print STDERR "No columns in '$csvfile'\n";
	}

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
	    my $specfile;
	    for my $spec (split ':', $opt->spec) {
		my $f = $spec . '/' . $specfiles->{$base}->{filename};
		if (-e $f) {
		    $specfile = $f;
		    last;
		}
	    }
	    print STDERR ("Opening spec file $specfile encoding: " . $opt->specencoding . "\n") if $opt->verbose;
	    if ($opt->use_bom) {
		open $fh, ("<:encoding(" . $opt->specencoding . "):via(File::BOM)"), $specfile;
	    } else {
		open $fh, ("<:encoding(" . $opt->specencoding . ")"), $specfile;
	    }
	    print STDERR "Done open" if $opt->verbose;
	    my %columns_spec = ();
	    $i = 0;
	    while (<$fh>) {
		next if /^\#/;
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
