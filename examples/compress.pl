#!/usr/bin/perl 
use strict;
use warnings;

use ApacheLog::Compressor 0.003;
use Sys::Hostname qw(hostname);

# Write all data to bzip2-compressed output file
open my $out_fh, '>', 'compressed.log' or die "Failed to create output file: $!";
binmode $out_fh;

# Provide a callback to send data through to the file
my $alc = ApacheLog::Compressor->new(
	on_write	=> sub {
		my ($self, $pkt) = @_;
		print { $out_fh } $pkt;
	},
	filter => sub {
		my ($self, $data) = @_;
		return 0 unless length $data->{url};
		return 0 unless $data->{timestamp};
		return 0 if $ApacheLog::Compressor::HTTP_METHOD_LIST[$data->{method}] eq 'OPTIONS' && $data->{url} eq '*';
		return 1;
	}
);

# Input file - normally use whichever one's just been closed + rotated
open my $fh, '<', shift(@ARGV) or die "Failed to open log: $!";

# Initial packet to identify which server this came from
$alc->send_packet('server',
	hostname	=> hostname(),
);

# Read and compress all the lines in the files
while(my $line = <$fh>) {
        $alc->compress($line);
}
close $fh or die $!;
close $out_fh or die $!;

# Dump the stats in case anyone finds them useful
$alc->stats;

