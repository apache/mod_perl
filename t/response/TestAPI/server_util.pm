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

    plan $r, tests => 2;

    my $t_dir = Apache::server_root_relative('conf', $r->pool);

    ok -d $t_dir;

    $t_dir = Apache::server_root_relative('logs');

    ok -d $t_dir;

    Apache::OK;
}

1;

__END__
