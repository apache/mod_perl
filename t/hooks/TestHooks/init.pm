package TestHooks::init;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

sub first {
    my $r = shift;

    $r->notes->set(ok1 => 1);

    Apache::OK;
}

sub second {
    my $r = shift;

    my $ok = $r->notes->get('ok1') || 0;

    $r->notes->set(ok2 => $ok + 1);

    Apache::OK;
}

sub handler {
    my $r = shift;

    my $ok = $r->notes->get('ok2') || 0;

    $r->notes->set(ok3 => $ok + 1);

    Apache::OK;
}

sub response {
    my $r = shift;

    my $tests = 3;
    plan $r, tests => $tests;

    for my $x (1..$tests) {
        my $val = $r->notes->get("ok$x") || 0;
        ok $val == $x;
    }

    Apache::OK;
}

1;
__DATA__
PerlInitHandler TestHooks::init::second
<Base>
    PerlInitHandler TestHooks::init::first
</Base>
PerlResponseHandler TestHooks::init::response
SetHandler modperl
