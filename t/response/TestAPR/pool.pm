package TestAPR::pool;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestTrace;

use Apache::RequestRec ();
use APR::Pool ();
use APR::Table ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 38;

    ### native pools ###

    # explicit and implicit DESTROY shouldn't destroy native pools
    {
        my $p = $r->pool;

        my $count = ancestry_count($p);
        t_debug "\$r->pool has 2 or more ancestors (found $count)";
        ok $count >= 2;

        $p->cleanup_register(\&set_cleanup, [$r, 'native DESTROY']);

        $p->DESTROY;

        my @notes = $r->notes->get('cleanup');

        ok t_cmp(0, scalar(@notes), "should be 0 notes");

        $r->notes->clear;
    }

    # implicit DESTROY shouldn't destroy native pools
    {
        {
            my $p = $r->pool;

            my $count = ancestry_count($p);
            t_debug "\$r->pool has 2 or more ancestors (found $count)";
            ok $count >= 2;

            $p->cleanup_register(\&set_cleanup, [$r, 'native scoped']);
        }

        my @notes = $r->notes->get('cleanup');

        ok t_cmp(0, scalar(@notes), "should be 0 notes");

        $r->notes->clear;
    }


    ### custom pools ###


    # test: explicit pool object DESTROY destroys the custom pool
    {
        my $p = APR::Pool->new;

        $p->cleanup_register(\&set_cleanup, [$r, 'new DESTROY']);

        ok t_cmp(1, ancestry_count($p),
                 "a new pool has one ancestor: the global pool");

        # explicity DESTROY the object
        $p->DESTROY;

        my @notes = $r->notes->get('cleanup');

        ok t_cmp(1, scalar(@notes), "should be 1 note");

        ok t_cmp('new DESTROY', $notes[0]);

        $r->notes->clear;
    }


    # test: lexical scoping DESTROYs the custom pool
    {
        {
            my $p = APR::Pool->new;

            ok t_cmp(1, ancestry_count($p),
                 "a new pool has one ancestor: the global pool");

            $p->cleanup_register(\&set_cleanup, [$r, 'new scoped']);
        }

        my @notes = $r->notes->get('cleanup');

        ok t_cmp(1, scalar(@notes), "should be 1 note");

        ok t_cmp('new scoped', $notes[0]);

        $r->notes->clear;
    }

    ### custom pools + sub-pools ###

    # test: basic pool and sub-pool tests + implicit destroy of pool objects
    {
        {
            my ($pp, $sp) = both_pools_create_ok($r);
        }

        both_pools_destroy_ok($r);

        $r->notes->clear;
    }


    # test: explicitly destroying a parent pool should destroy its
    # sub-pool
    {
        my ($pp, $sp) = both_pools_create_ok($r);

        # destroying $pp should destroy the subpool $sp too
        $pp->DESTROY;

        both_pools_destroy_ok($r);

        $r->notes->clear;
    }


    # test: destroying a sub-pool before the parent pool
    {
        my ($pp, $sp) = both_pools_create_ok($r);

        $sp->DESTROY;
        $pp->DESTROY;

        both_pools_destroy_ok($r);

        $r->notes->clear;
    }



    # test: destroying a sub-pool explicitly after the parent pool
    {
        my ($pp, $sp) = both_pools_create_ok($r);

        $pp->DESTROY;
        $sp->DESTROY;

        both_pools_destroy_ok($r);

        $r->notes->clear;
    }

    # other stuff
    {
        my $p = APR::Pool->new;

        # only available with -DAPR_POOL_DEBUG
        #my $num_bytes = $p->num_bytes;
        #ok $num_bytes;

    }

    Apache::OK;
}

# returns how many ancestor generations the pool has (parent,
# grandparent, etc.)
sub ancestry_count {
    my $child = shift;
    my $gen = 0;
    while (my $parent = $child->parent_get) {
        # prevent possible endless loops
        die "child pool reports to be its own parent, corruption!"
            if $parent == $child;
        $gen++;
        die "child knows its parent, but the parent denies having that child"
            unless $parent->is_ancestor($child);
        $child = $parent;
    }
    return $gen;
}

sub add_cleanup {
    my $arg = shift;
    debug "adding cleanup note";
    $arg->[0]->notes->add(cleanup => $arg->[1]);
    1;
}

sub set_cleanup {
    my $arg = shift;
    debug "setting cleanup note";
    $arg->[0]->notes->set(cleanup => $arg->[1]);
    1;
}

# +4 tests
sub both_pools_create_ok {
    my $r = shift;

    my $pp = APR::Pool->new;

    ok t_cmp(1, $pp->isa('APR::Pool'), "isa('APR::Pool')");

    ok t_cmp(1, ancestry_count($pp),
             "a new pool has one ancestor: the global pool");

    my $sp = $pp->new;

    ok t_cmp(1, $sp->isa('APR::Pool'), "isa('APR::Pool')");

    ok t_cmp(2, ancestry_count($sp),
             "a subpool has 2 ancestors: the parent and global pools");

    $pp->cleanup_register(\&add_cleanup, [$r, 'parent']);
    $sp->cleanup_register(\&set_cleanup, [$r, 'child']);

    return ($pp, $sp);

}

# +3 tests
sub both_pools_destroy_ok {
    my $r = shift;
    my @notes = $r->notes->get('cleanup');

    ok t_cmp(2, scalar(@notes), "should be 2 notes");
    ok t_cmp('child', $notes[0]);
    ok t_cmp('parent', $notes[1]);
}

1;
