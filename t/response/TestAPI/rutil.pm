package TestAPI::rutil;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::RequestUtil ();

use Apache::Const -compile => 'OK';

my %status_lines = (
   200 => '200 OK',
   400 => '400 Bad Request',
   500 => '500 Internal Server Error',
);

sub handler {
    my $r = shift;

    plan $r, tests => (scalar keys %status_lines) + 8;

    ok $r->default_type;

    ok $r->document_root;

    ok $r->get_server_name;

    ok $r->get_server_port;

    ok $r->get_limit_req_body || 1;

    ok $r->is_initial_req;

    my $pattern = qr!(?s)GET /TestAPI__rutil.*Host:.*200 OK.*Content-Type:!;

    ok t_cmp($r->as_string,
             $pattern,
             "test for the request_line, host, status, and few " .
             " headers that should always be there");

    while (my($code, $line) = each %status_lines) {
        ok t_cmp(Apache::RequestUtil::get_status_line($code),
                 $line,
                 "Apache::RequestUtil::get_status_line($code)");
    }

    t_debug('registering method FOO');
    ok Apache::RequestUtil::method_register($r->server->process->pconf, 'FOO');

    Apache::OK;
}

1;
