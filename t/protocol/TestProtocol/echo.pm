package TestProtocol::echo;

use strict;
use Apache::Connection ();
use APR::Socket ();

use constant BUFF_LEN => 1024;

sub handler {
    my Apache::Connection $c = shift;
    my APR::Socket $socket = $c->client_socket;

    my $buff;

    for (;;) {
        my($rlen, $wlen);
        my $rlen = BUFF_LEN;
        $socket->recv($buff, $rlen);
        last if $rlen <= 0;
        $wlen = $rlen;
        $socket->send($buff, $wlen);
        last if $wlen != $rlen;
    }

    return 0;
}

1;
