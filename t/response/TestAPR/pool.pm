package TestAPR::pool;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use Apache::RequestRec ();
use APR::Pool ();
use APR::Table ();

use Apache::Const -compile => 'OK';

sub add_cleanup {
    my $arg = shift;
    $arg->[0]->notes->add(cleanup => $arg->[1]);
    1;
}

sub set_cleanup {
    my $arg = shift;
    $arg->[0]->notes->set(cleanup => $arg->[1]);
    1;
}

sub handler {
    my $r = shift;

    plan $r, tests => 13;

    my $p = APR::Pool->new;

    ok $p->isa('APR::Pool');

    my $subp = $p->new;

    ok $subp->isa('APR::Pool');

#only available with -DAPR_POOL_DEBUG
#    my $num_bytes = $p->num_bytes;
#    ok $num_bytes;

    $p->cleanup_register(\&add_cleanup, [$r, 'parent']);
    $subp->cleanup_register(\&set_cleanup, [$r, 'child']);

    # should destroy the subpool too
    $p->destroy;

    my @notes = $r->notes->get('cleanup');
    ok $notes[0] eq 'child';
    ok $notes[1] eq 'parent';
    ok @notes == 2;

    # explicity DESTROY the objects
    my $p2 = APR::Pool->new;
    $p2->cleanup_register(\&set_cleanup, [$r, 'new DESTROY']);
    $p2->DESTROY;

    @notes = $r->notes->get('cleanup');
    ok $notes[0] eq 'new DESTROY';
    ok @notes == 1;

    # DESTROY should be a no-op on native pools
    my $p3 = $r->pool;
    $p3->cleanup_register(\&set_cleanup, [$r, 'native DESTROY']);
    $p3->DESTROY;

    @notes = $r->notes->get('cleanup');
    ok $notes[0] eq 'new DESTROY';    # same as before - no change
    ok @notes == 1;

    # make sure lexical scoping destroys the pool
    { 
        my $p4 = APR::Pool->new;
        $p4->cleanup_register(\&set_cleanup, [$r, 'new scoped']);
    }

    @notes = $r->notes->get('cleanup');
    ok $notes[0] eq 'new scoped';
    ok @notes == 1;

    # but doesn't affect native pools
    {
        my $p5 = $r->pool;
        $p5->cleanup_register(\&set_cleanup, [$r, 'native scoped']);
    }

    @notes = $r->notes->get('cleanup');
    ok $notes[0] eq 'new scoped';    # same as before - no change
    ok @notes == 1;

    Apache::OK;
}

1;
