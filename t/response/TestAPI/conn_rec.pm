package TestAPI::conn_rec;

# this test module is only for testing fields in the conn_rec listed
# in apache_structures.map (but some fields are tested in other tests)

use strict;
use warnings FATAL => 'all';

use Apache::TestUtil;
use Apache::Test;

use Apache::RequestRec ();
use Apache::RequestUtil ();
use Apache::Connection ();

use Apache::Const -compile => qw(OK CONN_CLOSE);

sub handler {
    my $r = shift;

    my $c = $r->connection;

    plan $r, tests => 14;

    ok $c;

    ok $c->pool->isa('APR::Pool');

    ok $c->base_server->isa('Apache::ServerRec');

    ok $c->client_socket->isa('APR::Socket');

    ok $c->local_addr->isa('APR::SockAddr');

    ok $c->remote_addr->isa('APR::SockAddr');

    ok $c->remote_ip;

    ok $c->remote_host || 1;

    ok !$c->aborted;

    ok t_cmp($c->keepalive,
             Apache::CONN_CLOSE,
             "the client has issued a non-keepalive request");

    ok $c->local_ip;

    ok $c->local_host || 1;

    t_debug "id", ($c->id == 0 ? "zero" : $c->id);
    ok $c->id || 1;

    ok $c->notes;

    # XXX: missing tests
    # conn_config

    Apache::OK;
}

1;
