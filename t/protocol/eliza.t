# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest ();

my @test_strings = ('Hello Eliza',
                    'How are you?',
                    'Why do I have core dumped?',
                    'I feel like writing some tests today, what about you?',
                    'Good bye, Eliza');

plan tests => 2 + @test_strings, need_module 'Chatbot::Eliza';

my $socket = Apache::TestRequest::vhost_socket('TestProtocol::eliza');

ok $socket;

for (@test_strings) {
    print $socket "$_\n";
    chomp(my $reply = <$socket> || '');
    t_debug "send: $_";
    t_debug "recv: $reply";
    ok $reply;
}

# at this point 'Good bye, Eliza' should abort the connection.
my $string = 'Eliza should not hear this';
print $socket "$string\n";
chomp(my $reply = <$socket> || '');
t_debug "Eliza shouldn't respond anymore";
ok !$reply;
