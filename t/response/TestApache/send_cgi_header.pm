package TestApache::send_cgi_header;

use strict;
use warnings FATAL => 'all';

use Apache::Response ();

use Apache::Const -compile => qw(OK);

sub handler {
    my $r = shift;

    my $response = <<EOF;
Content-type: text/plain
X-Foo: X-Bar
Set-Cookie: Bad Programmer, No cookie!

This not the end of the world
EOF

    # bah, we can send the header and the response here
    # don't tell anybody
    $r->send_cgi_header($response);

    Apache::OK;
}

1;
__END__
# this should work regardless whether parse headers is on or off
PerlOptions -ParseHeaders
