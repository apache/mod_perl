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

    plan $r, tests => 2;

    my $p = APR::Pool->new;

    ok $p->isa('APR::Pool');

#only available with -DAPR_POOL_DEBUG
#    my $num_bytes = $p->num_bytes;
#    ok $num_bytes;

    $p->cleanup_register(\&cleanup, 33);

    $p->destroy;

    Apache::OK;
}

1;
