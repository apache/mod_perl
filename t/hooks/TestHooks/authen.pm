package TestHooks::authen;

use strict;
use warnings FATAL => 'all';

use Apache::Access ();

sub handler {
    my $r = shift;

    my($rc, $sent_pw) = $r->get_basic_auth_pw;

    return $rc if $rc != 0;

    my $user = $r->user;

    unless ($user eq 'dougm' and $sent_pw eq 'foo') {
        $r->note_basic_auth_failure;
        return 401;
    }

    0;
}

1;
__DATA__
require valid-user
AuthType Basic
AuthName simple
PerlResponseHandler Apache::TestHandler::ok1
SetHandler modperl
