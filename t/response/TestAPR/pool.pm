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

    plan $r, tests => 76;

    ### native pools ###

    # explicit destroy shouldn't destroy native pools
    {
        my $p = $r->pool;

        my $count = ancestry_count($p);
        t_debug "\$r->pool has 2 or more ancestors (found $count)";
        ok $count >= 2;

        $p->cleanup_register(\&set_cleanup, [$r, 'native destroy']);

        $p->destroy;

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


    # test: explicit pool object destroy destroys the custom pool
    {
        my $p = APR::Pool->new;

        $p->cleanup_register(\&set_cleanup, [$r, 'new destroy']);

        ok t_cmp(1, ancestry_count($p),
                 "a new pool has one ancestor: the global pool");

        # explicity destroy the object
        $p->destroy;

        my @notes = $r->notes->get('cleanup');

        ok t_cmp(1, scalar(@notes), "should be 1 note");

        ok t_cmp('new destroy', $notes[0]);

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
        $pp->destroy;

        both_pools_destroy_ok($r);

        $r->notes->clear;
    }



    # test: destroying a sub-pool before the parent pool
    {
        my ($pp, $sp) = both_pools_create_ok($r);

        $sp->destroy;
        $pp->destroy;

        both_pools_destroy_ok($r);

        $r->notes->clear;
    }


    # test: destroying a sub-pool explicitly after the parent pool destroy

    # the parent pool should have already destroyed the child pool, so
    # the object is invalid
    {
        my ($pp, $sp) = both_pools_create_ok($r);

        $pp->destroy;
        $sp->destroy;

        both_pools_destroy_ok($r);

        $r->notes->clear;
    }


    # test: destroying a sub-pool before the parent pool and trying to
    # call APR::Pool methods on the a subpool object which points to a
    # destroyed pool
    {
        my ($pp, $sp) = both_pools_create_ok($r);

        # parent pool destroys child pool
        $pp->destroy;

        # this should "gracefully" fail, since $sp's guts were
        # destroyed when the parent pool was destroyed
        eval { $pp = $sp->parent_get };
        ok t_cmp(qr/invalid pool object/,
                 $@,
                 "parent pool destroys child pool");

        # since pool $sp now contains 0 pointer, if we try to make a
        # new pool out of it, it's the same as APR->new (i.e. it'll
        # use the global top level pool for it), so the resulting pool
        # should have an ancestry length of exactly 1
        my $ssp = $sp->new;
        ok t_cmp(1, ancestry_count($ssp),
                 "a new pool has one ancestor: the global pool");


        both_pools_destroy_ok($r);

        $r->notes->clear;
    }

    # test: make sure that one pool won't destroy/affect another pool,
    # which happened to be allocated at the same memory address after
    # the pointer to the first pool was destroyed
    {
        my $pp2;
        {
            my $pp = APR::Pool->new;
            $pp->destroy;
            # $pp2 ideally should take the exact place of apr_pool
            # previously pointed to by $pp
            $pp2 = APR::Pool->new;
            # $pp object didn't go away yet (it'll when exiting this
            # scope). in the previous implementation, $pp will be
            # destroyed second time on the exit of the scope and it
            # could happen to work, because $pp2 pointer has allocated
            # exactly the same address. and if so it would have killed
            # the pool that $pp2 points to

            # this should "gracefully" fail, since $pp's guts were
            # destroyed when the parent pool was destroyed
            # must make sure that it won't try to hijack the new pool
            # $pp2 that (hopefully) took over $pp's place
            eval { $pp->parent_get };
            ok t_cmp(qr/invalid pool object/,
                     $@,
                     "a dead pool is a dead pool");
        }

        # next make sure that $pp2's pool is still alive
        $pp2->cleanup_register(\&set_cleanup, [$r, 'overtake']);
        $pp2->destroy;

        my @notes = $r->notes->get('cleanup');

        ok t_cmp(1, scalar(@notes), "should be 1 note");
        ok t_cmp('overtake', $notes[0]);

        $r->notes->clear;

    }

    # test: similar to the previous test, but this time, the parent
    # pool destroys the child pool. a second allocation of a new pair
    # of the parent and child pools take over exactly the same
    # allocations. so if there are any ghost objects, they must not
    # find the other pools and use them as they own. for example they
    # could destroy the pools, and the perl objects of the pair would
    # have no idea that someone has destroyed the pools without their
    # knowledge. the previous implementation suffered from this
    # problem. the new implementation uses an SV which is stored in
    # the object and in the pool. when the pool is destroyed the SV
    # gets its IVX pointer set to 0, which affects any perl object
    # that is a ref to that SV. so once an apr pool is destroyed all
    # perl objects pointing to it get automatically invalidated and
    # there is no risk of hijacking newly created pools that happen to
    # be at the same memory address.

    {
        my ($pp2, $sp2);
        {
            my $pp = APR::Pool->new;
            my $sp = $pp->new;
            # parent destroys $sp
            $pp->destroy;

            # hopefully these pool will take over the $pp and $sp
            # allocations
            ($pp2, $sp2) = both_pools_create_ok($r);
        }

        # $pp and $sp shouldn't have triggered any cleanups
        my @notes = $r->notes->get('cleanup');
        ok t_cmp(0, scalar(@notes), "should be 0 notes");
        $r->notes->clear;

        # parent pool destroys child pool
        $pp2->destroy;

        both_pools_destroy_ok($r);

        $r->notes->clear;
    }

    # test: only when the last references to the pool object is gone
    # it should get destroyed
    {

        my $cp;

        {
            my $sp = $r->pool->new;

            $sp->cleanup_register(\&set_cleanup, [$r, 'several references']);

            $cp = $sp;
            # destroy of $sp shouldn't call apr_pool_destroy, because
            # $cp still references to it
        }

        my @notes = $r->notes->get('cleanup');
        ok t_cmp(0, scalar(@notes), "should be 0 notes");
        $r->notes->clear;

        # now the last copy is gone and the cleanup hooks will be called
        $cp->destroy;

        @notes = $r->notes->get('cleanup');
        ok t_cmp(1, scalar(@notes), "should be 1 note");
        ok t_cmp('several references', $notes[0]);

        $r->notes->clear;
    }
    {
        # and another variation
        my $pp = $r->pool->new;
        my $sp = $pp->new;

        my $gp  = $pp->parent_get;
        my $pp2 = $sp->parent_get;

        # parent destroys children
        $pp->destroy;

        # grand parent ($r->pool) is undestroyable (core pool)
        $gp->destroy;

        # now all custom pools are destroyed - $sp and $pp2 point nowhere
        $pp2->destroy;
        $sp->destroy;

        ok 1;
    }

    # cleanup_register using a function name as a callback
    {
        {
            my $p = APR::Pool->new;
            $p->cleanup_register('set_cleanup', [$r, 'function name']);
        }

        my @notes = $r->notes->get('cleanup');
        ok t_cmp('function name', $notes[0], "function name callback");

        $r->notes->clear;
    }

    # cleanup_register using an anon sub callback
    {
        {
            my $p = APR::Pool->new;

            $p->cleanup_register(sub { &set_cleanup }, [$r, 'anon sub']);
        }

        my @notes = $r->notes->get('cleanup');
        ok t_cmp('anon sub', $notes[0], "anon callback");

        $r->notes->clear;
    }

    # registered callbacks are run in reversed order LIFO
    {
        {
            my $p = APR::Pool->new;

            $p->cleanup_register(\&add_cleanup, [$r, 'first']);
            $p->cleanup_register(\&add_cleanup, [$r, 'second']);
        }

        my @notes = $r->notes->get('cleanup');
        ok t_cmp('second', $notes[0], "two cleanup functions");
        ok t_cmp('first',  $notes[1], "two cleanup functions");

        $r->notes->clear;
    }

    # bogus callbacks unfortunately will fail only when the pool is
    # destroyed, and we have no way to propogate (and thus trap) those
    # errors. They are logged though. So as usual, one has to always
    # watch error_log (things like CGI::Carp's fatalsToBrowser) won't
    # quite be able to catch those.
    {
        my $p = APR::Pool->new;
        t_server_log_error_is_expected();
        $p->cleanup_register('some_bogus_non_existing', 1);
    }
    {
        my $p = APR::Pool->new;
        t_server_log_error_is_expected();
        $p->cleanup_register(\&non_existing1, 1);
    }

    ### $p->clear ###
    {
        my ($pp, $sp) = both_pools_create_ok($r);
        $pp->clear;
        # both pools should have run their cleanups
        both_pools_destroy_ok($r);

        # sub-pool $sp should be now bogus, as clear() destroys
        # subpools
        eval { $sp->parent_get };
        ok t_cmp(qr/invalid pool object/,
                 $@,
                 "clear destroys sub pools");

        # now we should be able to use the parent pool without
        # allocating it
        $pp->cleanup_register(\&set_cleanup, [$r, 're-using pool']);
        $pp->destroy;

        my @notes = $r->notes->get('cleanup');
        ok t_cmp('re-using pool', $notes[0]);

        $r->notes->clear;
    }


    # a pool can be tagged, so when doing low level apr_pool tracing
    # (when apr is compiled with -DAPR_POOL_DEBUG) it's possible to
    # grep(1) for a certain tag, so it's a useful method
    {
        my $p = APR::Pool->new;
        $p->tag("my pool");

        # though there is no way we can get back the value to test,
        # since there is no apr_pool_tag read accessor
        ok 1;
    }




    # other stuff
    {
        my $p = APR::Pool->new;

        # find some method that wants a pool object and try to pass it
        # an object that was already destroyed e.g. APR::Table::make($p, 2);

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
    debug "adding cleanup note: $arg->[1]";
    $arg->[0]->notes->add(cleanup => $arg->[1]);
    1;
}

sub set_cleanup {
    my $arg = shift;
    debug "setting cleanup note: $arg->[1]";
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
