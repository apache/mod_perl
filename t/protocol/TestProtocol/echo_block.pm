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

    # make sure the socket is in the blocking mode for recv().
    # on some platforms (e.g. OSX/Solaris) httpd hands us a
    # non-blocking socket
    my $nonblocking = $socket->opt_get(APR::SO_NONBLOCK);
    if ($nonblocking) {
        $socket->opt_set(APR::SO_NONBLOCK => 0);

        # test that we really *are* in the blocking mode
        !$socket->opt_get(APR::SO_NONBLOCK)
            or die "failed to set blocking mode";
    }

    while (1) {
        my $buff = $socket->recv(BUFF_LEN);
        last unless length $buff; # EOF

        my $wlen = $socket->send($buff);
        last if $wlen != length $buff; # write failure?
    }

    Apache::OK;
}

1;
