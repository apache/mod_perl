use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest ();

my @test_strings = ('Hello Eliza', 
                    'How are you', 
                    'Why do I have core dumped?', 
                    'I feel like writing some tests today, you?',
                    'good bye');

plan tests => 1 + @test_strings, test_module 'Chatbot::Eliza';

my $socket = Apache::TestRequest::vhost_socket('TestProtocol::eliza');

ok $socket;

for (@test_strings) {
    print "SEND ='$_'\n";
    print $socket "$_\n";
    chomp(my $reply = <$socket>);
    print "REPLY='$reply'\n";
    ok $reply;
}
