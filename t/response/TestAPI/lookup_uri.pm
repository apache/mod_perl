package TestAPI::lookup_uri;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use Apache::SubRequest ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    my $uri = '/lookup_uri';
    my $subr = $r->lookup_uri($uri);
    die unless $subr->uri eq $uri;
    $subr->run;

    Apache::OK;
}

1;
__DATA__
<Location /lookup_uri>
   SetHandler modperl
   PerlResponseHandler Apache::TestHandler::ok1
</Location>
