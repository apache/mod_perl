package TestAPI::server_util;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::ServerUtil ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    my $s = $r->server;

    plan $r, tests => 3;

    my $dir = Apache::server_root_relative('conf', $r->pool);

    ok -d $dir;

    $dir = Apache::server_root_relative('logs');

    ok -d $dir;

    $dir = Apache::server_root_relative();

    ok -d $dir;

    Apache::OK;
}

1;

__END__
