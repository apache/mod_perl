package TestAPI::rutil;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

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

sub handler {
    my $r = shift;

    plan $r, tests => 17;

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

    Apache::OK;
}

1;
