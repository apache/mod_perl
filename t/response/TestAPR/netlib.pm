package TestAPR::netlib;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use APR::NetLib ();

sub handler {
    my $r = shift;
    my $c = $r->connection;
    my $p = $r->pool;

    plan $r, tests => 3;

    my $ip = $c->remote_ip;

    ok $ip;

    my $ipsub = APR::IpSubnet->new($p, $ip);

    ok $ipsub->test($c->remote_addr);

    $ipsub = APR::IpSubnet->new($p, scalar reverse $ip);

    ok ! $ipsub->test($c->remote_addr);

    0;
}

1;
