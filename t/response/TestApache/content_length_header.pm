package TestApache::content_length_header;

# see the client for the comments

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::Response ();

use Apache::Const -compile => 'OK';

my $body = "This is a response string";

sub handler {
    my $r = shift;

    $r->content_type('text/plain');

    my $args = $r->args || '';

    if ($args =~ /set_content_length/) {
        $r->set_content_length(length $body);
    }

    if ($args =~ /send_body/) {
        # really could send just about anything, since Apache discards
        # the response body on HEAD requests
        $r->print($body);
    }

    Apache::OK;
}

1;
