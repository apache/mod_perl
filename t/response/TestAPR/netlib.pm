package TestAPR::netlib;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::Connection ();
use Apache::RequestRec ();

use APR::NetLib ();
use APR::SockAddr ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;
    my $c = $r->connection;
    my $p = $r->pool;

    plan $r, tests => 4;

    my $ip = $c->remote_ip;

    ok $ip;

    ok t_cmp($ip, $c->remote_addr->ip_get,
             "remote_ip eq remote_addr->ip_get");

    my $ipsub = APR::IpSubnet->new($p, $ip);

    ok $ipsub->test($c->remote_addr);

    $ipsub = APR::IpSubnet->new($p, scalar reverse $ip);

    ok ! $ipsub->test($c->remote_addr);

    Apache::OK;
}

1;
