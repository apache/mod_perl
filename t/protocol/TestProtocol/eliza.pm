package TestProtocol::eliza;

use strict;
use warnings FATAL => 'all';

use Apache::Connection ();
use APR::Socket ();

require Chatbot::Eliza;

use Apache::Const -compile => 'OK';

use constant BUFF_LEN => 1024;

my $mybot = new Chatbot::Eliza;

sub handler {
    my Apache::Connection $c = shift;
    my APR::Socket $socket = $c->client_socket;

    my $buff;
    my $last = 0;
    for (;;) {
        my($rlen, $wlen);
        $rlen = BUFF_LEN;
        $socket->recv($buff, $rlen);
        last if $rlen <= 0;
        chomp $buff;
        $last++ if $buff eq 'good bye';
        $buff = $mybot->transform( $buff ) . "\n";
        $socket->send($buff, length $buff);
        last if $last;
    }

    Apache::OK;
}

1;
