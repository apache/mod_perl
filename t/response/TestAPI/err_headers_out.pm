package TestAPI::err_headers_out;

# tests: $r->err_headers_out

# when sending a non-2xx response one must use $r->err_headers_out to
# set extra headers

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestUtil ();
use APR::Table ();

use Apache::Const -compile => qw(OK NOT_FOUND);

sub handler {
    my $r = shift;

    # this header will make it
    $r->err_headers_out->add('X-Survivor' => "err_headers_out");

    # this header won't make it
    $r->headers_out->add('X-Goner' => "headers_out");

    return Apache::NOT_FOUND;
}

1;
__END__
