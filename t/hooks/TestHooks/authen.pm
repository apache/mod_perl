package TestHooks::authen;

use strict;
use warnings FATAL => 'all';

use Apache::Access ();
use Apache::Const -compile => qw(OK AUTH_REQUIRED SERVER_ERROR);

sub handler {
    my $r = shift;

    my($rc, $sent_pw) = $r->get_basic_auth_pw;

    return $rc if $rc != Apache::OK;

    my $user = $r->user;

    my $requirement = $r->requires->[0]->{requirement};

    return Apache::SERVER_ERROR unless $requirement eq 'valid-user';

    unless ($user eq 'dougm' and $sent_pw eq 'foo') {
        $r->note_basic_auth_failure;
        return Apache::AUTH_REQUIRED;
    }

    Apache::OK;
}

1;
__DATA__
require valid-user
AuthType Basic
AuthName simple
PerlResponseHandler Apache::TestHandler::ok1
SetHandler modperl
