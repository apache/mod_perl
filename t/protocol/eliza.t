use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest ();

my @test_strings = ('Hello Eliza', 
                    'How are you', 
                    'Why do I have core dumped?', 
                    'I feel like writing some tests today, you?',
                    'good bye');

plan tests => 1 + @test_strings, have_module 'Chatbot::Eliza';

my $socket = Apache::TestRequest::vhost_socket('TestProtocol::eliza');

ok $socket;

for (@test_strings) {
    print $socket "$_\n";
    chomp(my $reply = <$socket>);
    t_debug "send: $_";
    t_debug "recv: $reply";
    ok $reply;
}
