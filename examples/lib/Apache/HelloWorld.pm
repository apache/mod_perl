package Apache::HelloWorld;

#<Location /hello-world>
#  SetHandler modperl
#  PerlResponseHandler Apache::HelloWorld
#</Location>

use strict;
use Apache::RequestRec (); #for $r->content_type
use Apache::RequestIO ();  #for $r->puts

sub handler {
    my $r = shift;

    $r->content_type('text/plain');

    #send_http_header API function does not exist in 2.0

    $r->puts(__PACKAGE__); #print not yet implemented

    0; #constants not yet implemented
}

1;
