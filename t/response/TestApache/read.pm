package TestApache::read;

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();

use Apache::Const -compile => 'OK';

use constant BUFSIZ => 512; #small for testing

sub handler {
    my $r = shift;
    $r->content_type('text/plain');

    my $ct = $r->headers_in->get('content-length');
    my $buffer = "";
    my $bufsiz = $r->args || BUFSIZ;

    while ((my($offset) = length($buffer)) < $ct) {
        my $remain = $ct - $offset;
        my $len = $remain >= $bufsiz ? $bufsiz : $remain;
        last unless $len > 0;
        $r->read($buffer, $len, $offset);
    }

    #make sure we dont block after all data is read
    my $n = $r->read(my $x, BUFSIZ);
    die unless $n == 0;

    $r->puts($buffer);

    Apache::OK;
}

1;
