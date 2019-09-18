package WeelibJSONRecordGenerator;

$VERSION     = 1.00;
@ISA         = qw(RecordGenerator Exporter);
@EXPORT      = qw();
@EXPORT_OK   = qw();


use strict;
use RecordGenerator;
use Exporter;
use JSON::MaybeXS qw(decode_json);
use MARC::Record;
use CommonMarcMappings;
use MarcUtil::MarcMappingCollection;
use REST::Client;
use CHI;
use URI;
use URI::QueryParam;
require Encode;

my $mmc = MarcUtil::MarcMappingCollection::marc_mappings(%common_marc_mappings);

$mmc->mappings->{'huvuduppslag_personnamn'}->ind1('1');

sub init {
    my $self = shift;

    $self->SUPER::init();
    $self->{curjson_array} = undef;
    $self->{curjson_index} = 0;

    $self->{skoltermer} = REST::Client->new();
    $self->{skoltermer}->setHost('http://skoltermer.se');
    $self->{skoltermer}->addHeader('Accept' => 'application/json');
    $self->{skoltermer_cache} = CHI->new( driver => 'File',
					  root_dir => '/var/cache/libra2koha/skoltermer',
					  defaults => {
					      expire_in => 'never'
					  });
}

sub reset {
    my $self = shift;

    $self->SUPER::reset();

    $self->{curjson_array} = undef;
    $self->{curjson_index} = 0;
}

sub next {
    my $self = shift;

    my $jsonobj = $self->next_jsonobj;

    if (defined $jsonobj) {
	my $record = $self->to_marc($jsonobj);
	if (!defined $record) {
	    return $self->next;
	}
	return $record;
    }

    return undef;
}

sub next_jsonobj {
    my $self = shift;

    unless (defined $self->{curjson_array} && scalar(@{$self->{curjson_array}}) > $self->{curjson_index}) {
	my $file = $self->nextfile;

	unless (defined $file) {
	    return undef;
	}

	local $/ = undef;
	open FILE, "<:encoding(iso-8859-1)", $file or die "Couldn't open '$file' for reading: $!";
	my $content = <FILE>;
	close FILE;
	my $jsonobj = decode_json($content);

	if (!defined $jsonobj) {
	    die "$file doesn't contain valid json.";
	}

	if (ref $jsonobj ne 'ARRAY') {
	    die "$file doesn't contain an array of json objects.";
	}
	$self->{curjson_array} = $jsonobj;
	$self->{curjson_index} = 0;
    }

    return $self->{curjson_array}->[$self->{curjson_index}++];
}

sub to_marc {
    my $self = shift;
    my $jsonobj = shift;

    my $record = MARC::Record->new();
    $record->encoding('UTF-8');
    $mmc->record($record);

    for my $k (keys %$jsonobj) {
	if ($k eq '_class' or $k eq 'createdBy') {
	} elsif ($k eq '_id' or $k eq 'member' or $k eq 'describes') {
	} elsif ($k eq 'sourceId') {
	} elsif ($k eq 'sourceRecordId') {
	    $mmc->set('bibid', $jsonobj->{$k});
	} elsif ($k eq 'sourceName') {
	    $mmc->set('syscode', $jsonobj->{$k});
	} elsif ($k eq 'sourceModifiedDate') {
	} elsif ($k eq 'deleted') {
	    return undef if $jsonobj->{$k};
	} elsif ($k eq 'status') {
	} elsif ($k eq 'createdDate') {
	} elsif ($k eq 'modifiedDate') {
	} elsif ($k eq 'modifiedBy') {
	} elsif ($k eq 'version') {
	} elsif ($k eq 'metadataCached' or $k eq 'metadataLocal') {
	    for my $i (@{$jsonobj->{$k}}) {
		for my $m (keys %$i) {
		    my $setlistsub = sub {
			my $subfield = shift;
			my $key = shift;
			my @names = map {$_->{$subfield}} @{$i->{$m}};
			$mmc->set($key, @names);
		    };
		    my $setlist = sub {
			my $key = shift;
			$mmc->set($key, @{$i->{$m}});
		    };
		    my $setskolterm = sub {
			my $key = shift;
			my @termer = map {$self->fetch_skoltermer($_)} @{$i->{$m}};
			$mmc->set($key, @termer);
		    };
		    if ($m eq 'dctContributor' || $m eq 'dctCreator') {
			$setlistsub->('name', 'huvuduppslag_personnamn');
		    } elsif ($m eq 'dctCreated') {
		    } elsif ($m eq 'dctDescription') {
			$setlistsub->('value', 'anmärkning_abstract');
		    } elsif ($m eq 'dctFormat') {
		    } elsif ($m eq 'dctModified') {
		    } elsif ($m eq 'dctIdentifier') {
		    } elsif ($m eq 'dctHasPart') {
		    } elsif ($m eq 'dctLanguage') {
			$setskolterm->('anmärkning_språk');
		    } elsif ($m eq 'dctPublisher') {
			$setlistsub->('name', 'namn_på_utgivare');
		    } elsif ($m eq 'dctSubject') {
			$setskolterm->('anmärkning_ämne');
		    } elsif ($m eq 'dctReferences') {
			my @refs = map { s|^/local/||; $_ } @{$i->{$m}};
			$mmc->set('länkning_annat_samband_bibid', @refs);
		    } elsif ($m eq 'dctRights') {
			$setskolterm->('villkor_för_användning_och_reproduktion');
		    } elsif ($m eq 'dctTitle') {
			my @titlar = map { $_->{value} } @{$i->{$m}};
			$mmc->set('titel', @titlar);
		    } elsif ($m eq 'dctType') {
			$setskolterm->('biblioitemtype');
		    } elsif ($m eq 'mlr4Location') {
		    } elsif ($m eq 'mlr5Audience') {
			my @ages = map { my $s = $_->{minimumAge} . '-' . $_->{maximumAge} . ' år'; Encode::_utf8_on($s); $s } (grep { defined $_->{minimumAge} && defined $_->{maximumAge}} @{$i->{$m}});
			my @levels = map { $_->{audienceLevels} } (grep { defined $_->{audienceLevels} } @{$i->{$m}});
			my @targets = ();
			for my $l (@levels) {
			    push @targets, map { $self->fetch_skoltermer($_) } @$l;
			}
			$mmc->set('anmärkning_målgrupp', @targets);
			$mmc->set('anmärkning_målgrupp_åldersnivå', @ages);
		    } elsif ($m eq 'mlr5LearningMethod') {
			$setskolterm->('anmärkning_metodik');
		    } elsif ($m eq 'mlr5Curriculum') {
			my @vals = map {$_->{levels}}  @{$i->{$m}};
			$mmc->set('anmärkning_publikationer_om_det_beskrivna_materialet', @vals);
		    } elsif ($m eq 'biboIsbn') {
			$setlist->('isbn');
		    } elsif ($m eq 'biboIssn') {
			$setlist->('issn');
		    } elsif ($m eq 'biboVolume') {
			$mmc->set('titel_delbeteckning', $i->{$m});
		    } elsif ($m eq 'biboShortTitle') {
			$setlistsub->('value', 'förkortad_titel');
		    } elsif ($m eq 'biboShortDescription') {
			$setlistsub->('value', 'anmärkning_abstract');
		    } elsif ($m eq 'axPublisherId') {
		    } elsif ($m eq 'axGenre') {
			$setskolterm->('indexterm_genre_form');
		    } elsif ($m eq 'axHolding') {
		    } elsif ($m eq 'axIframeSrc') {
		    } elsif ($m eq 'axEpisodeNumber') {
			$mmc->set('titel_delbeteckning', $i->{$m});
		    } elsif ($m eq 'axSortPublicationYear') {
		    } elsif ($m eq 'axTitleSeries') {
			$setlist->('serietitel');
		    } elsif ($m eq 'axTitleOriginal') {
			$mmc->set('originaltitel', $i->{$m});
		    } elsif ($m eq 'axTitleOrginal') {
			$mmc->set('originaltitel', $i->{$m});
		    } elsif ($m eq 'axTargetGroup') {
			$setskolterm->('anmärkning_målgrupp_åldersnivå');
		    } elsif ($m eq 'axResourceType') {
			my $leader = $record->leader();
			if ($i->{$m} =~ /=581$/) {
			    # Digital media
			    substr($leader, 6, 1, 'm');
			    $record->leader($leader);
			} elsif ($i->{$m} =~ /=486$/) {
			    # Fysisk media
			}
		    } elsif ($m eq 'axSortAuthor') {
		    } elsif ($m eq 'axDewey') {
			$setlist->('klassifikationskod_dewey');
		    } elsif ($m eq 'axSab') {
			$setlist->('klassifikationskod');
		    } elsif ($m eq 'axSubject') {
			$setlist->('ämnesord');
		    } elsif ($m eq 'axNote') {
			$mmc->set('anmärkning_allmän');
		    } elsif ($m eq 'axThumbnail') {
		    } elsif ($m eq 'dctDate') {
			$mmc->set('utgivningstid', @{$i->{$m}});
		    } else {
			die "Don't know what to do with medatata local '$m' of value '"  . $i->{$m} . "'";
		    }
		}
	    }
	} else {
	    die "Don't know what to do with '$k' of value '" . $jsonobj->{$k} . "'";
	}
    }


    return clean_record($record);
}

sub fetch_skoltermer {
    my $self = shift;
    my $url = shift;

    return '' if ($url eq '');

    return $url if not $url =~ m|://skoltermer\.se/|;

    my $uri = URI->new($url);

    my $term = $uri->query_param('tema');

    unless (defined $term) {
	warn "Term not defined in url: '$url'" ;
	return '';
    }

    my $obj = $self->{skoltermer_cache}->get($term);
    return $obj if defined $obj;

    my $res = $self->{skoltermer}->GET('/aem/services.php?output=json&task=fetchTerms&arg=' . $term);
    if ($self->{skoltermer}->responseCode != 200) {
	die "Failed to fetch term $term: " . $self->{skoltermer}->responseCode;
    }

    my $content = $self->{skoltermer}->responseContent();

    $obj = decode_json($content);

    die "Failed to decode json" unless defined $obj;

    my $val = $obj->{result}->{$term}->{string};

    $self->{skoltermer_cache}->set($term, $val);
    
    return $val;
}

sub num_records {
    my $self = shift;
    my $n = 0;
    while ($self->next_jsonobj) {
	$n++;
    }
    $self->reset;
    return $n;
}

sub clean_record {
    my $record = shift;
    my $cleaned = 0;
    for my $field ($record->fields) {
	my $pos = 0;
	for my $subfield ($field->subfields) {
	    if ($subfield->[1] eq '') {
		$field->delete_subfield(code => $subfield->[0], pos => $pos);
		$cleaned = 1;
	    } else {
		$pos++;
	    }
	}
	if (!$field->is_control_field && (!defined $field->subfields || scalar($field->subfields) == 0)) {
	    $record->delete_fields($field);
	    $cleaned = 1;
	}
    }
    return $record;
}

sub close {
}

1;
