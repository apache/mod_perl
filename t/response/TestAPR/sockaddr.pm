package TestAPR::sockaddr;

# testing APR::SockAddr API

use strict;
use warnings  FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::Connection ();
use Apache::RequestRec ();
use APR::SockAddr ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;
    my $c = $r->connection;

    plan $r, tests => 4;

    my $local  = $c->local_addr;
    my $remote = $c->remote_addr;

    ok t_cmp($c->local_ip,  $local->ip_get,  "local ip");
    ok t_cmp($c->remote_ip, $remote->ip_get, "remote ip");

    $r->subprocess_env;
    ok t_cmp($ENV{SERVER_PORT}, $local->port,  "local port");
    ok t_cmp($ENV{REMOTE_PORT}, $remote->port, "remote port");

    Apache::OK;
}

1;
