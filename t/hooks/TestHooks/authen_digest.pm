package TestHooks::authen_digest;

use strict;
use warnings FATAL => 'all';

use Apache::Access ();
use Apache::RequestRec ();

use Apache::Const -compile => qw(OK HTTP_UNAUTHORIZED);

sub handler {

    my $r = shift;

    # we don't need to do the entire Digest auth round
    # trip just to see if note_digest_auth_failure is
    # functioning properly - see authen_digest.t for the
    # header checks
    if ($r->args) {
        $r->note_digest_auth_failure;
        return Apache::HTTP_UNAUTHORIZED;
    }

    return Apache::OK;
}

1;
__DATA__
<NoAutoConfig>
<Location /TestHooks__authen_digest>
    PerlAuthenHandler TestHooks::authen_digest
    PerlResponseHandler Apache::TestHandler::ok
    SetHandler modperl

    require valid-user
    AuthType Digest
    AuthName "Simple Digest"
</Location>
</NoAutoConfig>
