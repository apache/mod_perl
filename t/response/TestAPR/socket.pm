package TestAPR::socket;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::RequestRec ();
use Apache::Connection ();
use APR::Socket ();

use Apache::Const -compile => 'OK';
use APR::Const -compile => 'EMISMATCH';

sub handler {
    my $r = shift;

    my $tests = 4;

    plan $r, tests => $tests;

    my $c = $r->connection;
    my $socket = $c->client_socket;

    ok $socket;


    # in microseconds
    my $orig_val = $socket->timeout_get();
    t_debug "orig timeout was: $orig_val";
    ok $orig_val;

    my $new_val = 30_000_000; # 30 secs
    $socket->timeout_set($new_val);
    ok t_cmp($new_val, $socket->timeout_get(), "timeout_get()");

    # reset the timeout
    $socket->timeout_set($orig_val);
    ok t_cmp($orig_val, $socket->timeout_get(), "timeout_get()");

    Apache::OK;
}

1;
