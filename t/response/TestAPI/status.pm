package TestAPI::status;

# see the client for details

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();

use Apache::Const -compile => 'OK';

my $body = "This is a response string";

sub handler {
    my $r = shift;

    $r->content_type('text/plain');

    my($code, $string) = split /=/, $r->args || '';

    if ($string) {
        $r->status(200); # status_line should override status
        $r->status_line("$code $string");
    }
    else {
        $r->status($code);
    }

    Apache::OK;
}

1;
