package TestAPI::conn_rec;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use Apache::Const -compile => 'OK';

#this test module is only for testing fields in the conn_rec
#listed in apache_structures.map

sub handler {
    my $r = shift;

    my $c = $r->connection;

    plan $r, tests => 15;

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

    Apache::OK;
}

1;
