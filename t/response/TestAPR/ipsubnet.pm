package TestAPR::ipsubnet;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::Connection ();
use Apache::RequestRec ();

use APR::IpSubnet ();
use APR::SockAddr ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;
    my $c = $r->connection;
    my $p = $r->pool;

    plan $r, tests => 5;

    my $ip = $c->remote_ip;

    ok $ip;

    ok t_cmp($ip, $c->remote_addr->ip_get,
             "remote_ip eq remote_addr->ip_get");

    my $ipsub = APR::IpSubnet->new($p, $ip);

    ok $ipsub->test($c->remote_addr);

    my $reverse_remote_ip = scalar reverse $ip;

    ok t_cmp($reverse_remote_ip, scalar reverse($c->remote_addr->ip_get),
             "reversed remote_ip eq reversed remote_addr->ip_get");

    $ipsub = APR::IpSubnet->new($p, $reverse_remote_ip);

    if (!$ipsub) {
        ok 1; #this happens on win32
    }
    else {
        ok ! $ipsub->test($c->remote_addr);
    }

    Apache::OK;
}

1;
