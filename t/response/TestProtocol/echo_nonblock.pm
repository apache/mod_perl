package TestProtocol::echo_nonblock;

# this test reads from/writes to the socket doing nonblocking IO

use strict;
use warnings FATAL => 'all';

use Apache::Connection ();
use APR::Socket ();
use APR::Error ();

use Apache::TestTrace;

use Apache::Const -compile => 'OK';
use APR::Const    -compile => qw(SO_NONBLOCK TIMEUP SUCCESS POLLIN
                                 ECONNABORTED);

use constant BUFF_LEN => 1024;

sub handler {
    my $c = shift;
    my $socket = $c->client_socket;

    $socket->opt_set(APR::SO_NONBLOCK, 1);

    my $counter = 0;
    my $timeout = 0;
    while (1) {

        debug "counter: $counter";
        if ($counter == 1) {
            # this will certainly cause timeout
            $timeout = 0;
        } else {
            # Wait up to ten seconds for data to arrive.
            $timeout = 10_000_000;
        }
        $counter++;

        my $rc = $socket->poll($c->pool, $timeout, APR::POLLIN);
        if ($rc == APR::SUCCESS) {
            my $buf;
            my $len = eval { $socket->recv($buf, BUFF_LEN) };
            if ($@) {
                die $@ unless ref $@ eq 'APR::Error'
                    && $@ == APR::ECONNABORTED; # rethrow
                # ECONNABORTED is not an application error
                # XXX: we don't really test that we always get this
                # condition, since it depends on the timing of the
                # client closing the socket. may be it'd be possible
                # to make sure that APR::ECONNABORTED was received
                # when $counter == 2 if we have slept enough, but how
                # much is enough is unknown
                debug "caught '104: Connection reset by peer' error";
                last;
            }

            last unless $len;

            debug "sending: $buf";
            $socket->send($buf);
        }
        elsif ($rc == APR::TIMEUP) {
            debug "timeout";
            $socket->send("TIMEUP\n");
        }
        else {
            die "poll error: $rc: " . APR::Error::strerror($rc);
        }
    }

    Apache::OK;
}

1;
