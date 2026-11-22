# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestProtocol::eliza;

use strict;
use warnings FATAL => 'all';

use Apache2::Connection ();
use APR::Socket ();

require Chatbot::Eliza;

use Apache2::Const -compile => 'OK';
use APR::Const     -compile => 'SO_NONBLOCK';

use constant BUFF_LEN => 1024;

my $mybot = new Chatbot::Eliza;

sub handler {
    my Apache2::Connection $c = shift;
    my APR::Socket $socket = $c->client_socket;

    # starting from Apache 2.0.49 several platforms require you to set
    # the socket to a blocking IO mode
    my $nonblocking = $socket->opt_get(APR::Const::SO_NONBLOCK);
    if ($nonblocking) {
        $socket->opt_set(APR::Const::SO_NONBLOCK, 0);

        # test that we really *are* in the blocking mode
        !$socket->opt_get(APR::Const::SO_NONBLOCK)
            or die "failed to set blocking mode";
    }

    my $last = 0;
    while ($socket->recv(my $buff, BUFF_LEN)) {
        # \r is sent instead of \n if the client is talking over telnet
        $buff =~ s/[\r\n]*$//;
        $last++ if $buff eq "Good bye, Eliza";
        $buff = $mybot->transform( $buff ) . "\n";
        $socket->send($buff);
        last if $last;
    }

    Apache2::Const::OK;
}

1;
