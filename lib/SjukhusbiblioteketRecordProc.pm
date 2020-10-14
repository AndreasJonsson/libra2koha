package SjukhusbiblioteketRecordProc;

import RecordUtils;

sub new {
    my ($class, $opt) = @_;
    return bless {
	opt => $opt
    };
}

sub process {
    my ($self, $mmc, $record) = @_;



}

1;
