package TestAPR::bucket;

# a mix of APR::Brigade, APR::Bucket abd APR::BucketType tests

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use APR::Brigade ();
use APR::Bucket ();
use APR::BucketType ();
use Apache::Connection ();
use Apache::RequestRec ();

use Apache::Const -compile => 'OK';

use TestAPRlib::bucket;

sub handler {

    my $r = shift;

    plan $r, tests => 18 + TestAPRlib::bucket::num_of_tests();

    TestAPRlib::bucket::test();

    my $ba = $r->connection->bucket_alloc;

    # eos_create / type / length
    {
        my $b = APR::Bucket::eos_create($ba);
        my $type = $b->type;
        ok t_cmp($type->name, 'EOS', "eos_create");

        ok t_cmp($b->length, 0, "eos b->length");

        # buckets with no data to read should return an empty string
        my $rlen = $b->read(my $read);
        ok t_cmp($read, "", 'eos b->read/buffer');
        ok t_cmp($rlen, 0, 'eos b->read/len');
    }

    # flush_create
    {
        my $b = APR::Bucket::flush_create($ba);
        my $type = $b->type;
        ok t_cmp($type->name, 'FLUSH', "flush_create");

        ok t_cmp($b->length, 0, "flush b->length");
    }

    # insert_after / insert_before / is_eos / is_flush
    {
        my $d1 = APR::Bucket->new("d1");
        my $d2 = APR::Bucket->new("d2");
        my $f1 = APR::Bucket::flush_create($ba);
        my $f2 = APR::Bucket::flush_create($ba);
        my $e1 = APR::Bucket::eos_create($ba);

        ### create a chain of buckets
        my $bb = APR::Brigade->new($r->pool, $ba);

        $bb->insert_head($d1);

        # d1->d2
        $d1->insert_after($d2);

        # d1->f1->f2
        $d2->insert_before($f1);

        # d1->f1->d2->f2
        $d2->insert_after($f2);

        # d1->f1->d2->f2->e1
        $bb->insert_tail($e1);

        ### now test

        my $b = $bb->first;
        $b->read(my $read);
        ok t_cmp($read, "d1", "d1 bucket");

        $b = $bb->next($b);
        t_debug("is_flush");
        ok $b->is_flush;

        $b = $bb->next($b);
        $b->read($read);
        ok t_cmp($read, "d2", "d2 bucket");

        $b = $bb->last();
        t_debug("is_eos");
        ok $b->is_eos;

        $b = $bb->prev($b);
        t_debug("is_flush");
        ok $b->is_flush;

        t_debug("not empty");
        ok !$bb->is_empty;

        # remove all buckets from bb and test that it's empty
        for (my $b = $bb->first; $b; $b = $bb->next($b)) {
            $b->remove;
        }
        t_debug("empty");
        ok $bb->is_empty;
    }

    # check for non-existing buckets first/next/last
    {
        my $bb = APR::Brigade->new($r->pool, $ba);

        ok t_cmp($bb->first, undef, "no first bucket");
        ok t_cmp($bb->last,  undef, "no last bucket");

        ## now there is first
        my $b = APR::Bucket->new("bbb");
        $bb->insert_head($b);
        my $b_first = $bb->first;
        $b->read(my $read);
        ok t_cmp($read, "bbb", "first bucket");

        # but there is no prev
        ok t_cmp($bb->prev($b_first), undef, "no prev bucket");

        # and no next
        ok t_cmp($bb->next($b_first), undef, "no next bucket");
    }

    return Apache::OK;
}

1;
