package TestAPI::request_rec;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

sub handler {
    my $r = shift;

    plan $r, tests => 33;

    ok $r->pool->isa('APR::Pool');

    ok $r->connection->isa('Apache::Connection');

    ok $r->server->isa('Apache::Server');

    for (qw(next prev main)) {
        ok (! $r->$_()) || $r->$_()->isa('Apache::RequestRec');
    }

    ok $r->the_request || 1;

    ok $r->assbackwards || 1;

    ok $r->proxyreq || 1;

    ok $r->header_only || 1;

    ok $r->protocol =~ /http/i;

    ok $r->proto_num;

    ok $r->hostname || 1;

    ok $r->request_time;

    ok $r->status_line || 1;

    ok $r->status || 1;

    ok $r->method;

    ok $r->method_number || 1;

    ok $r->allowed || 1;

    #allowed_xmethods
    #allow_methods

    ok $r->bytes_sent || 1;

    ok $r->mtime || 1;

    ok $r->headers_in;

    ok $r->headers_out;

    ok $r->err_headers_out;

    ok $r->subprocess_env;

    ok $r->notes;

    ok $r->content_type;

    ok $r->handler;

    #content_encoding
    #content_language
    #content_languages

    #user

    #no_cache
    #no_local_copy

    ok $r->unparsed_uri;

    ok $r->uri;

    ok $r->filename;

    ok $r->path_info || 1;

    ok $r->args || 1;

    #finfo
    #parsed_uri

    #per_dir_config
    #request_config

    #output_filters
    #input_filers

    #eos_sent

    0;
}

1;
