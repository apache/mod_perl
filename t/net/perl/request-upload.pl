use strict;
use Apache::test;

my $r = shift;
$r->send_http_header('text/plain');

eval {
    require Apache::Request;
};

unless (Apache::Request->can('upload')) {
    print "1..0\n";
    print $@ if $@;
    print "$INC{'Apache/Request.pm'}\n";
    return;
}

my $apr = Apache::Request->new($r);

for ($apr->param) {
    my(@v) = $apr->param($_);
    print "param $_ => @v\n";
}

for (my $upload = $apr->upload; $upload; $upload = $upload->next) {
    my $fh = $upload->fh;
    my $filename = $upload->filename;
    my $name = $upload->name;
    my $type = $upload->type;
    print "$name $filename ($type)";
    if ($fh and $name) {
	no strict;
	if (my $no = fileno($filename)) {
	    print " fileno => $no";
	}
    }
    print "\n";
}

my $first = $apr->upload->name;
my $first_filename = $apr->upload->filename;
my $first_fh = $apr->upload->fh;
while (<$first_fh>) { }

for my $upload ($apr->upload) {
    my $fh = $upload->fh;
    my $filename = $upload->filename;
    my $name = $upload->name;
    my($lines, $bytes);
    $lines = $bytes = 0;

    {
	no strict;
	if (fileno($filename)) {
	    $fh = *$filename{IO};
	    print "COMPAT: $fh\n";
	} 
    }
    use File::Basename;
    local *OUT;
    if (my $dir = $apr->header_in("X-Upload-Tmp")) {
	if (-d $dir) {
	    Apache->untaint($dir);
	    my $file = basename $filename;
	    open OUT, ">$dir/$file" or die $!;
	}
    }
    while(<$fh>) {
	++$lines;
	$bytes += length;
	print OUT $_ if fileno OUT;
    }
    close OUT;

    my $info = $upload->info;
    while (my($k,$v) = each %$info) {
	print "INFO: $k => $v\n";
    }
    unless ($name eq $first) {
	print "-" x 40, $/;
	my $info = $apr->upload($first)->info;
	print "Lookup `$first':[$info]\n";
	while (my($k,$v) = each %$info) {
	    print "INFO: $k => $v\n";
	}
	my $type = $apr->uploadInfo($first_filename, "content-type");
	unless ($type) {
	    die "uploadInfo is broken";
	} 
	print "TYPE: $type\n";
	print "-" x 40, $/;
    }
    my $wanted = $upload->size;
    unless ($bytes == $wanted) {
	die "wanted $wanted bytes, got $bytes bytes";
    }
    print "Server: Lines: $lines\n";
    print "$filename bytes=$bytes,wanted=$wanted\n";
}

