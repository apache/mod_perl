package TestProtocol::eliza;

use strict;
use warnings FATAL => 'all';

use Apache2::Connection ();
use APR::Socket ();

require Chatbot::Eliza;

use Apache2::Const -compile => 'OK';

use constant BUFF_LEN => 1024;

my $mybot = new Chatbot::Eliza;

sub handler {
    my Apache2::Connection $c = shift;
    my APR::Socket $socket = $c->client_socket;

    my $last = 0;
    while ($socket->recv(my $buff, BUFF_LEN)) {
        # \r is sent instead of \n if the client is talking over telnet
        $buff =~ s/[\r\n]*$//;
        $last++ if $buff eq "Good bye, Eliza";
        $buff = $mybot->transform( $buff ) . "\n";
        $socket->send($buff);
        last if $last;
    }

    Apache2::OK;
}

1;
