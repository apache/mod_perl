package TestHooks::init;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use APR::Table ();
use Apache::RequestRec ();

use Apache::Const -compile => qw(OK DECLINED);

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

    Apache::DECLINED;
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
<NoAutoConfig>
  <VirtualHost TestHooks::init>
    PerlModule      TestHooks::init
    PerlInitHandler TestHooks::init::first
    <Location /TestHooks__init>
        PerlInitHandler TestHooks::init::second
        PerlResponseHandler TestHooks::init
        PerlResponseHandler TestHooks::init::response
        SetHandler modperl
    </Location>
  </VirtualHost>
</NoAutoConfig>
