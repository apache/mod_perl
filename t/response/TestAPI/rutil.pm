package TestAPI::rutil;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use APR::URI ();
use Apache::RequestUtil ();

use Apache::Const -compile => 'OK';

my %default_ports = (
    http => 80,
    https => 443,
    ftp => 21,
    gopher => 70,
    wais => 210,
    nntp => 119,
    snews => 563,
    prospero => 191,
);

sub handler {
    my $r = shift;

    plan $r, tests => 15;

    ok $r->default_type;

    ok $r->document_root;

    ok $r->get_server_name;

    ok $r->get_server_port;

    ok $r->get_limit_req_body || 1;

    while(my($scheme, $port) = each %default_ports) {
        my $apr_port = APR::URI::port_of_scheme($scheme);
        #$r->puts("$scheme => expect: $port, got: $apr_port\n");
        ok $apr_port == $port;
    }

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
