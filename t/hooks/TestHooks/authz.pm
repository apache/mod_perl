package TestHooks::authz;

use strict;
use warnings FATAL => 'all';

use Apache::Access ();
use Apache::Const -compile => qw(OK AUTH_REQUIRED);

sub auth_any {
    my $r = shift;

    my($res, $sent_pw) = $r->get_basic_auth_pw;
    return $res if $res != Apache::OK;

    unless($r->user and $sent_pw) {
	$r->note_basic_auth_failure;
	return Apache::AUTH_REQUIRED;
    }

    return Apache::OK;
}

sub handler {
    my $r = shift;

    my $user = $r->user;

    return Apache::AUTH_REQUIRED unless $user;

    my($u, @allowed) = split /\s+/, $r->requires->[0]->{requirement};

    return Apache::AUTH_REQUIRED unless grep { $_ eq $user } @allowed;

    Apache::OK;
}

1;
__DATA__
require user dougm
AuthType Basic
AuthName simple
PerlAuthenHandler   TestHooks::authz::auth_any
PerlResponseHandler Apache::TestHandler::ok1
SetHandler modperl
