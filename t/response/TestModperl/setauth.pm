package TestModperl::setauth;

use strict;
use warnings FATAL => 'all';

use Apache::Access ();

use Apache::Test;
use Apache::TestUtil;

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 2;

    ok t_cmp(undef, $r->auth_type(), 'auth_type');

    t_server_log_error_is_expected();
    $r->get_basic_auth_pw();

    ok t_cmp('Basic', $r->auth_type(), 'default auth_type');

    Apache::OK;
}

1;
