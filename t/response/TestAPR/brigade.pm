package TestAPR::brigade;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::RequestRec ();
use APR::Brigade ();

use Apache::Const -compile => 'OK';

sub handler {

    my $r = shift;

    plan $r, tests => 4;

    # simple constructor and accessor tests

    my $bb = APR::Brigade->new($r->pool, $r->connection->bucket_alloc);

    t_debug('$bb is defined');
    ok defined $bb;

    t_debug('$bb ISA APR::Brigade object');
    ok $bb->isa('APR::Brigade');

    my $pool = $bb->pool;

    t_debug('$pool is defined');
    ok defined $pool;

    t_debug('$pool ISA APR::Pool object');
    ok $pool->isa('APR::Pool');

    Apache::OK;
}

1;
