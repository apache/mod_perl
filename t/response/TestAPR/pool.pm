package TestAPR::pool;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use APR::Pool ();

use Apache::Const -compile => 'OK';

sub cleanup {
    my $arg = shift;
    ok $arg == 33;
}

sub handler {
    my $r = shift;

    plan $r, tests => 4;

    my $p = APR::Pool->new;

    ok $p->isa('APR::Pool');

    my $subp = $p->new;

    ok $subp->isa('APR::Pool');

#only available with -DAPR_POOL_DEBUG
#    my $num_bytes = $p->num_bytes;
#    ok $num_bytes;

    $p->cleanup_register(\&cleanup, 33);
    $subp->cleanup_register(\&cleanup, 33);

    # should destroy the subpool too, so
    # cleanup is called twice
    $p->destroy;

    Apache::OK;
}

1;
