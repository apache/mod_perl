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

my %status_lines = (
   200 => '200 OK',
   400 => '400 Bad Request',
   500 => '500 Internal Server Error',
);

use constant HAVE_APACHE_2_0_40 => have_apache_version("2.0.40");

sub handler {
    my $r = shift;

    plan $r, tests => 18;

    ok $r->default_type;

    ok $r->document_root;

    ok $r->get_server_name;

    ok $r->get_server_port;

    ok $r->get_limit_req_body || 1;

    while(my($scheme, $port) = each %default_ports) {
        my $apr_port = APR::URI::default_port_for_scheme($scheme);
        #$r->puts("$scheme => expect: $port, got: $apr_port\n");
        ok $apr_port == $port;
    }

    while (my($code, $line) = each %status_lines) {
        ok Apache::get_status_line($code) eq $line;
    }

    ok $r->is_initial_req;

    # XXX: Apache 2.0.40 seems to miss status and content-type
    my $pattern = HAVE_APACHE_2_0_40
        ? qr!(?s)GET /TestAPI__rutil.*Host:.*!
        : qr!(?s)GET /TestAPI__rutil.*Host:.*200 OK.*Content-Type:!;
    ok t_cmp(
        $pattern,
        $r->as_string,
        "test for the request_line, host, status, and few " .
        " headers that should always be there"
    );

    Apache::OK;
}

1;
