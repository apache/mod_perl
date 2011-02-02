package TestAPI::conn_rec;

# this test module is only for testing fields in the conn_rec listed
# in apache_structures.map (but some fields are tested in other tests)

use strict;
use warnings FATAL => 'all';

use Apache::TestUtil;
use Apache::Test;

use Apache2::RequestRec ();
use Apache2::RequestUtil ();
use Apache2::Connection ();

use Apache2::Const -compile => qw(OK CONN_CLOSE);

sub handler {
    my $r = shift;

    my $c = $r->connection;

    plan $r, tests => 16;

    ok $c;

    ok $c->pool->isa('APR::Pool');

    ok $c->base_server->isa('Apache2::ServerRec');

    ok $c->client_socket->isa('APR::Socket');

    ok $c->local_addr->isa('APR::SockAddr');

    ok $c->remote_addr->isa('APR::SockAddr');

    # remote_ip
    {
        my $remote_ip_org = $c->remote_ip;
        my $remote_ip_new = "10.10.10.255";
        ok $remote_ip_org;

        $c->remote_ip($remote_ip_new);
        ok t_cmp $c->remote_ip, $remote_ip_new;

        # restore
        $c->remote_ip($remote_ip_org);
        ok t_cmp $c->remote_ip, $remote_ip_org;
    }

    ok $c->remote_host || 1;

    ok !$c->aborted;

    ok t_cmp($c->keepalive,
             Apache2::Const::CONN_CLOSE,
             "the client has issued a non-keepalive request");

    ok $c->local_ip;

    ok $c->local_host || 1;

    t_debug "id ", ($c->id == 0 ? "zero" : $c->id);
    ok $c->id || 1;

    ok $c->notes;

    # XXX: missing tests
    # conn_config

    Apache2::Const::OK;
}

1;
