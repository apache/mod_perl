use strict;
use warnings FATAL => 'all';

use Test;
use Apache::TestUtil;
use Apache::TestRequest ();

plan tests => 3;

my $socket = Apache::TestRequest::vhost_socket('TestProtocol::echo_nonblock');

ok $socket;

my $received;
my $expected;

$expected = "nonblocking";
print $socket "$expected\n";
chomp($received = <$socket> || '');
ok t_cmp $received, $expected, "no timeout";

# now get a timed out request
$expected = "TIMEUP";
print $socket "should timeout\n";
chomp($received = <$socket> || '');
ok t_cmp $received, $expected, "timed out";

