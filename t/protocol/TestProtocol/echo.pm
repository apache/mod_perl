package TestProtocol::echo;

use strict;
use warnings FATAL => 'all';

use Apache::Connection ();
use APR::Socket ();

use Apache::Const -compile => 'OK';
use APR::Const    -compile => qw(SO_NONBLOCK);

use constant BUFF_LEN => 1024;

sub handler {
    my Apache::Connection $c = shift;
    my APR::Socket $socket = $c->client_socket;

    my $buff;

    # make sure the socket is in the blocking mode for recv().
    # on some platforms (e.g. OSX/Solaris) httpd hands us a
    # non-blocking socket
    $socket->opt_set(APR::SO_NONBLOCK, 0);

    for (;;) {
        my($rlen, $wlen);
        $rlen = BUFF_LEN;
        $socket->recv($buff, $rlen);
        last if $rlen <= 0;
        $wlen = $rlen;
        $socket->send($buff, $wlen);
        last if $wlen != $rlen;
    }

    Apache::OK;
}

1;
