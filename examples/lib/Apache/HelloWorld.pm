package Apache::HelloWorld;

#<Location /hello-world>
#  SetHandler modperl
#  PerlResponseHandler Apache::HelloWorld
#</Location>

sub handler {
    my $r = shift;

    $r->content_type('text/plain');

    #send_http_header API function does not exist in 2.0

    $r->puts(__PACKAGE__); #print not yet implemented

    0; #constants not yet implemented
}

1;
