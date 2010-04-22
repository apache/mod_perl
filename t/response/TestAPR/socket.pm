package TestAPR::socket;

# more tests in t/protocol/TestProtocol/echo_*.pm

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache2::RequestRec ();
use Apache2::Connection ();
use APR::Socket ();

use Apache2::Const -compile => 'OK';
use APR::Const -compile => 'EMISMATCH';

sub handler {
    my $r = shift;

    my $tests = 5;

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
    ok t_cmp($socket->timeout_get(), $new_val, "timeout_get()");

    # reset the timeout
    $socket->timeout_set($orig_val);
    ok t_cmp($socket->timeout_get(), $orig_val, "timeout_get()");

    my $fd=$socket->fileno;
    t_debug "client socket fd=$fd";
    if ($^O eq 'MSWin32') {
        ok $fd==-1;
    }
    else {
        ok $fd>=0;
    }

    Apache2::Const::OK;
}

1;
