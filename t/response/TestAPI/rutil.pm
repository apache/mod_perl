package TestAPI::rutil;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::RequestUtil ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 7;

    ok $r->default_type;

    ok $r->document_root;

    ok $r->get_server_name;

    ok $r->get_server_port;

    ok $r->get_limit_req_body || 1;

    ok $r->is_initial_req;

    my $pattern = qr!(?s)GET /TestAPI__rutil.*Host:.*200 OK.*Content-Type:!;

    ok t_cmp(
        $pattern,
        $r->as_string,
        "test for the request_line, host, status, and few " .
        " headers that should always be there"
    );

    Apache::OK;
}

1;
