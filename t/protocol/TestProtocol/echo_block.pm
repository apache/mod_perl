package TestProtocol::echo_block;

# this test reads from/writes to the socket doing blocking IO
#
# see TestProtocol::echo_timeout for how to do the same with
# nonblocking IO but using the timeout

use strict;
use warnings FATAL => 'all';

use Apache::Connection ();
use APR::Socket ();

use Apache::Const -compile => 'OK';
use APR::Const    -compile => qw(SO_NONBLOCK TIMEUP EOF);

use constant BUFF_LEN => 1024;

sub handler {
    my Apache::Connection $c = shift;
    my APR::Socket $socket = $c->client_socket;

    # starting from Apache 2.0.49 several platforms require you to set
    # the socket to a blocking IO mode
    my $nonblocking = $socket->opt_get(APR::SO_NONBLOCK);
    if ($nonblocking) {
        $socket->opt_set(APR::SO_NONBLOCK => 0);

        # test that we really *are* in the blocking mode
        !$socket->opt_get(APR::SO_NONBLOCK)
            or die "failed to set blocking mode";
    }

    while ($socket->recv(my $buff, BUFF_LEN)) {
        $socket->send($buff);
    }

    Apache::OK;
}

1;
