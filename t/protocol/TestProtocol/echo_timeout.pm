package TestProtocol::echo_timeout;

# this test reads from/writes to the socket doing nonblocking IO but
# using the timeout
#
# see TestProtocol::echo_block for how to do the same with blocking IO

use strict;
use warnings FATAL => 'all';

use Apache::Connection ();
use APR::Socket ();

use Apache::Const -compile => 'OK';
use APR::Const    -compile => qw(TIMEUP);

use constant BUFF_LEN => 1024;

sub handler {
    my Apache::Connection $c = shift;
    my APR::Socket $socket = $c->client_socket;

    # set timeout (20 sec) so later we can do error checking on
    # read/write timeouts
    $socket->timeout_set(20_000_000);

    my ($buff, $rlen, $wlen, $rc);
    for (;;) {
        $rlen = BUFF_LEN;
        $rc = $socket->recv($buff, $rlen);
        die "timeout on socket read" if $rc == APR::TIMEUP;
        last if $rlen <= 0;

        $wlen = $rlen;
        $rc = $socket->send($buff, $wlen);
        die "timeout on socket write" if $rc == APR::TIMEUP;

        last if $wlen != $rlen;
    }

    Apache::OK;
}

1;
