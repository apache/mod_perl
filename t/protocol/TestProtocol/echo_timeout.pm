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
use APR::Const    -compile => qw(TIMEUP SO_NONBLOCK);

use constant BUFF_LEN => 1024;

sub handler {
    my Apache::Connection $c = shift;
    my APR::Socket $socket = $c->client_socket;

    # starting from Apache 2.0.49 several platforms require you to set
    # the socket to a blocking IO mode
    $c->client_socket->opt_set(APR::SO_NONBLOCK => 0);

    # set timeout (20 sec) so later we can do error checking on
    # read/write timeouts
    $socket->timeout_set(20_000_000);

    while (1) {
        my $buff = eval { $socket->recv(BUFF_LEN) };
        if ($@) {
            die "timed out, giving up: $@" if $@ == APR::TIMEUP;
            die $@;
        }

        last unless length $buff; # EOF

        my $wlen = eval { $socket->send($buff) };
        if ($@) {
            die "timed out, giving up: $@" if $@ == APR::TIMEUP;
            die $@;
        }
        last if $wlen != length $buff; # write failure?
    }

    Apache::OK;
}

1;
