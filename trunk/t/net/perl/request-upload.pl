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
    my $name = $upload->name;
    my $type = $upload->type;
    print "$name ($type)";
    if ($fh and $name) {
	no strict;
	if (my $no = fileno($name)) {
	    print " fileno => $no";
	}
    }
    print "\n";
}

my $first = $apr->upload->name;
for my $upload ($apr->upload) {
    my $fh = $upload->fh;
    my $name = $upload->name;
    my($lines, $bytes);
    $lines = $bytes = 0;

    {
	no strict;
	if (fileno($name)) {
	    $fh = *$name{IO};
	    print "COMPAT: $fh\n";
	} 
    }
    while(<$fh>) {
	++$lines;
	$bytes += length;
    }

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
	my $type = $apr->uploadInfo($first, "content-type");
	print "TYPE: $type\n";
	print "-" x 40, $/;
    }
    my $wanted = $upload->size;
    print "Server: Lines: $lines\n";
    print "$name bytes=$bytes,wanted=$wanted\n";
}

