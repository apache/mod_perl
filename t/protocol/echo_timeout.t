use strict;
use warnings FATAL => 'all';

use Test;
use Apache::TestUtil;
use Apache::TestRequest ();

my @test_strings = qw(good bye cruel world);

plan tests => 1 + @test_strings;

my $socket = Apache::TestRequest::vhost_socket('TestProtocol::echo_timeout');

ok $socket;

for (@test_strings) {
    print $socket "$_\n";
    chomp(my $reply = <$socket>||'');
    ok t_cmp($_, $reply);
}
