package TestAPI::server_util;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::RequestRec ();
use Apache::ServerUtil ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    my $s = $r->server;

    plan $r, tests => 9;

    for my $p ($r->pool, $r->connection->pool,
               $r, $r->connection, $r->server)
    {
        my $dir = Apache::server_root_relative($p, 'conf');

        ok -d $dir;
    }

    my $dir = Apache::server_root; #constant

    ok -d $dir;

    $dir = join '/', Apache::server_root, 'logs';

    ok $dir eq Apache::server_root_relative($r->pool, 'logs');

    $dir = Apache->server_root_relative('logs'); #1.x ish

    ok -d $dir;

    #$r->server_root_relative works with use Apache::compat
    $dir = Apache->server_root_relative(); #1.x ish

    ok -d $dir;

    Apache::OK;
}

1;

__END__
