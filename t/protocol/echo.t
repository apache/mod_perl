use strict;
use warnings FATAL => 'all';

use Test;
use Apache::TestRequest ();

my @test_strings = qw(hello world);

plan tests => 1 + @test_strings;

my $socket = Apache::TestRequest::vhost_socket('TestProtocol::echo');

ok $socket;

for (@test_strings) {
    print "SEND ='$_'\n";
    print $socket "$_\n";
    chomp(my $reply = <$socket>);
    print "REPLY='$reply'\n";
    ok $reply eq $_;
}
