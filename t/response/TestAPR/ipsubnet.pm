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

    plan $r, tests => 7;

    my $ip = $c->remote_ip;

    ok $ip;

    ok t_cmp($c->remote_addr->ip_get, $ip,
             "remote_ip eq remote_addr->ip_get");

    {
        my $ipsub = APR::IpSubnet->new($p, $ip);

        ok $ipsub->test($c->remote_addr);
    }

    # use IP mask
    {
        my $ipsub = APR::IpSubnet->new($p, $ip, "255.0.0.0");

        ok $ipsub->test($c->remote_addr);
    }

    # fail match
    {
        if ($ip =~ /^\d+\.\d+\.\d+\.\d+$/) {
            # arrange for the subnet to match only one IP, which is
            # one digit off the client IP, ensuring a mismatch
            (my $mismatch = $ip) =~ s/(?<=\.)(\d+)$/$1 == 255 ? $1-1 : $1+1/e;
            t_debug($mismatch);
            my $ipsub = APR::IpSubnet->new($p, $mismatch, $mismatch);
            ok ! $ipsub->test($c->remote_addr);
        }
        else {
            # XXX: similar ipv6 trick?
            ok 1;
        }
    }

    # bogus IP
    {
        my $ipsub = eval { APR::IpSubnet->new($p, "345.234.678.987") };
        ok t_cmp($@, qr/The specified IP address is invalid/, "bogus IP");
    }

    # bogus mask
    {
        my $ipsub = eval { APR::IpSubnet->new($p, $ip, "255.0") };
        ok t_cmp($@, qr/The specified network mask is invalid/, "bogus mask");
    }

    Apache::OK;
}

1;
