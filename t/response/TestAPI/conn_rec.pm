package TestAPI::conn_rec;

use strict;
use warnings FATAL => 'all';

use Apache::TestUtil;
use Apache::Test;

use Apache::RequestRec ();
use Apache::RequestUtil ();
use Apache::Connection ();

use Apache::Const -compile => qw(OK REMOTE_HOST REMOTE_NAME
    REMOTE_NOLOOKUP REMOTE_DOUBLE_REV);

#this test module is only for testing fields in the conn_rec
#listed in apache_structures.map

sub handler {
    my $r = shift;

    my $c = $r->connection;

    plan $r, tests => 22;

    ok $c;

    ok $c->pool->isa('APR::Pool');

    ok $c->base_server->isa('Apache::Server');

    ok $c->client_socket->isa('APR::Socket');

    ok $c->local_addr->isa('APR::SockAddr');

    ok $c->remote_addr->isa('APR::SockAddr');

    ok $c->remote_ip;

    ok $c->remote_host || 1;

    ok $c->remote_logname || 1;

    ok $c->aborted || 1;

    ok $c->keepalive || 1;

    ok $c->local_ip;

    ok $c->local_host || 1;

    ok $c->id || 1;

    #conn_config

    ok $r->notes;

    #input_filters
    #output_filters
    #remain

    # Connection utils (XXX: move to conn_utils.pm?)

    # $c->get_remote_host
    ok $c->get_remote_host() || 1;

    for (Apache::REMOTE_HOST, Apache::REMOTE_NAME, 
        Apache::REMOTE_NOLOOKUP, Apache::REMOTE_DOUBLE_REV) {
        ok $c->get_remote_host($_) || 1;
    }

    ok $c->get_remote_host(Apache::REMOTE_HOST, 
        $c->base_server->dir_config) || 1;
    ok $c->get_remote_host(Apache::REMOTE_HOST, $r->dir_config) || 1;

    Apache::OK;
}

1;
