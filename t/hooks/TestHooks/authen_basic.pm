package TestHooks::authen_basic;

use strict;
use warnings FATAL => 'all';

use Apache2::Access ();

use Apache2::Const -compile => qw(OK HTTP_UNAUTHORIZED SERVER_ERROR);

sub handler {
    my $r = shift;

    my ($rc, $sent_pw) = $r->get_basic_auth_pw;

    return $rc if $rc != Apache2::Const::OK;

    my $user = $r->user;

    my $requirement = $r->requires->[0]->{requirement};

    return Apache2::Const::SERVER_ERROR unless $requirement eq 'valid-user';

    unless ($user eq 'dougm' and $sent_pw eq 'foo') {
        $r->note_basic_auth_failure;
        return Apache2::Const::HTTP_UNAUTHORIZED;
    }

    Apache2::Const::OK;
}

1;
__DATA__
<NoAutoConfig>
<Location /TestHooks__authen_basic>
    require valid-user
    AuthType Basic
    AuthName simple
    PerlAuthenHandler TestHooks::authen_basic
    PerlResponseHandler Apache::TestHandler::ok1
    SetHandler modperl
</Location>
</NoAutoConfig>
