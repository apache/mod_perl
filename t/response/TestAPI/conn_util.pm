package TestAPI::conn_util;

use strict;
use warnings FATAL => 'all';

use Apache::TestUtil;
use Apache::Test;

use Apache::RequestRec ();
use Apache::RequestUtil ();
use Apache::Connection ();

use Apache::Const -compile => qw(OK REMOTE_HOST REMOTE_NAME
    REMOTE_NOLOOKUP REMOTE_DOUBLE_REV);

sub handler {
    my $r = shift;

    my $c = $r->connection;

    plan $r, tests => 7;

    ok $c->get_remote_host() || 1;

    for (Apache::REMOTE_HOST, Apache::REMOTE_NAME,
        Apache::REMOTE_NOLOOKUP, Apache::REMOTE_DOUBLE_REV) {
        ok $c->get_remote_host($_) || 1;
    }

    ok $c->get_remote_host(Apache::REMOTE_HOST,
                           $r->per_dir_config) || 1;
    ok $c->get_remote_host(Apache::REMOTE_HOST, $r->per_dir_config) || 1;

    Apache::OK;
}

1;
