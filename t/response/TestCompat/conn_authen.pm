package TestCompat::conn_authen;

# simply check that we can retrieve:
#   $r->connection->auth_type
#   $r->connection->user
# both records don't exist in 2.0 conn_rec and therefore require
# 'PerlOptions +GlobalRequest' to retrieve those via Apache->request

use strict;
use warnings FATAL => 'all';

use Apache::TestUtil;
use Apache::Test;

use Apache::compat ();
use Apache::Constants qw(OK REMOTE_HOST);

sub handler {
    my $r = shift;

    my($rc, $sent_pw) = $r->get_basic_auth_pw;

    return $rc if $rc != Apache::OK;

    my $auth_type = $r->connection->auth_type || '';
    die "auth_type is '$auth_type', should be 'Basic'" 
        unless $auth_type eq 'Basic';

    my $user = $r->connection->user || '';
    die "user is '$user', while expecting 'dougm'"
        unless $user eq 'dougm';

    OK;
}

1;

__DATA__
require valid-user
AuthType Basic
AuthName simple
SetHandler modperl
PerlOptions +GlobalRequest
PerlAuthenHandler TestCompat::conn_authen
PerlResponseHandler Apache::TestHandler::ok1

