package TestAPI::access;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache2::Access ();

use Apache2::Const -compile => qw(OK :options :override :satisfy);

sub handler {
    my $r = shift;

    plan $r, tests => 11;

    $r->allow_methods(1, qw(GET POST));

    ok 1;

    ok $r->allow_options & Apache2::OPT_INDEXES;

    ok !($r->allow_options & Apache2::OPT_EXECCGI);

    ok !($r->allow_overrides & Apache2::OR_LIMIT);

    ok t_cmp $r->satisfies, Apache2::SATISFY_NOSPEC, "satisfies";

    ok t_cmp $r->auth_name, 'modperl', "auth_name";

    $r->auth_name('modperl_test');
    ok t_cmp $r->auth_name, 'modperl_test', "auth_name";
    $r->auth_name('modperl');

    ok t_cmp $r->auth_type,  'none', "auth_type";

    $r->auth_type('Basic');
    ok t_cmp $r->auth_type, 'Basic', "auth_type";
    $r->auth_type('none');

    ok !$r->some_auth_required;

    # XXX: this test requires a running identd, which we have no way
    # to figure out whether it's running, or how to start one. so for
    # now just check that the method is call-able.
    my $remote_logname = $r->get_remote_logname() || '';
    t_debug "get_remote_logname: $remote_logname";
    ok 1;

    Apache2::OK;
}

1;
__END__
Options None
Options Indexes FollowSymLinks
AuthName modperl
AuthType none

# this directive was moved from core in Apache 2.1
# since we're not testing that identd is running
# anyway we probably don't need to include it at all
#IdentityCheck On
