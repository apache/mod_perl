package TestAPI::custom_response;

# custom_response() doesn't alter the response code, but is used to
# replace the standard response body

use strict;
use warnings FATAL => 'all';

use Apache::Response ();

use Apache::Const -compile => qw(FORBIDDEN);

sub handler {
    my $r = shift;

    my $how = $r->args || '';
    # warn "$how";
    # could be text or url
    $r->custom_response(Apache::FORBIDDEN, $how);

    return Apache::FORBIDDEN;
}

1;
__END__
<NoAutoConfig>
<Location /TestAPI__custom_response>
    AuthName dummy
    AuthType none
    PerlAccessHandler TestAPI::custom_response
</Location>
</NoAutoConfig>

