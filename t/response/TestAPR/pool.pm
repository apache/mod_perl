package TestAPR::pool;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use Apache::Const -compile => 'OK';
use APR::Pool ();

sub cleanup {
    my $arg = shift;
    ok $arg == 33;
}

sub handler {
    my $r = shift;

    plan $r, tests => 3;

    my $p = APR::Pool->new;

    ok $p->isa('APR::Pool');

    my $num_bytes = $p->num_bytes;

    ok $num_bytes;

    $p->cleanup_register(\&cleanup, 33);

    $p->destroy;

    Apache::OK;
}

1;
