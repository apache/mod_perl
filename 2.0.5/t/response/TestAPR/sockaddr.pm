package TestAPR::sockaddr;

# testing APR::SockAddr API

use strict;
use warnings  FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache2::Connection ();
use Apache2::RequestRec ();
use APR::SockAddr ();

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;
    my $c = $r->connection;

    plan $r, tests => 4;

    my $local  = $c->local_addr;
    my $remote = $c->remote_addr;

    ok t_cmp($local->ip_get,  $c->local_ip,  "local ip");
    ok t_cmp($remote->ip_get, $c->remote_ip, "remote ip");

    $r->subprocess_env;
    ok t_cmp($local->port,  $ENV{SERVER_PORT}, "local port");
    ok t_cmp($remote->port, $ENV{REMOTE_PORT}, "remote port");

    Apache2::Const::OK;
}

1;
