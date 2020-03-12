package RecordGenerator;

sub new {
    my ($class, $args) = @_;

    my $self = bless {
	args => $args,
	opt => $args->{opt},
	files => $args->{files},
	curfile => 0
    }, $class;
    $self->init();
    return $self;
}

sub init {
}
    
sub nextfile {
    my $self = shift;

    my @files = @{$self->{files}};

    if (scalar(@files) <= $self->{curfile}) {
	return undef;
    }

    my $file = $files[$self->{curfile}++];
    
    return $file;
}

sub reset {
    my $self = shift;
    $self->close;
    $self->{curfile} = 0;
}


sub num_records {
    my $self = shift;

    my $n = 0;
    while ($self->next()) {
	$n++;
    }
    $self->reset();
    return $n;
}

1;
