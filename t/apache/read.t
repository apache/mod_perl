use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 1;

my $location = "/TestApache::read";

my $socket = Apache::TestRequest::vhost_socket('default');

$socket->autoflush(1);

my $file = '../pod/modperl_2.0.pod';

open(my $fh, $file) or die "open $file: $!";

my $data = join '', <$fh>;
close $fh;
my $size = length $data;

print $socket "POST $location http/1.0\r\n";
print $socket "Content-length: $size\r\n";
print $socket "\r\n";

my $written = 0;
my $bufsiz = 240;

my $sleeps = 2;

while ($written < length($data)) {
    my $remain = length($data) - $written;
    my $len = $remain > $bufsiz ? $bufsiz : $remain;
    $written += syswrite($socket, $data, $len, $written);
    sleep 1 if $sleeps-- > 0;
}

while (<$socket>) {
    last if /^\015?\012$/; #skip over headers
}

my $return = join '', <$socket>;

ok $data eq $return;
