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

sub handler {

    my $r = shift;

    plan $r, tests => 26;

    my $ba = $r->connection->bucket_alloc;

    # new: basic
    {
        my $data = "foobar";
        my $b = APR::Bucket->new($data);

        t_debug('$b is defined');
        ok defined $b;

        t_debug('$b ISA APR::Bucket object');
        ok $b->isa('APR::Bucket');

        my $type = $b->type;
        ok t_cmp('mod_perl SV bucket', $type->name, "type");

        ok t_cmp(length($data), $b->length, "modperl b->length");
    }

    # new: offset
    {
        my $data   = "foobartar";
        my $offset = 3;
        my $real = substr $data, $offset;
        my $b = APR::Bucket->new($data, $offset);
        my $read = $b->read;
        ok t_cmp($real, $read, 'new($data, $offset)');
        ok t_cmp($offset, $b->start, 'offset');

    }

    # new: offset+len
    {
        my $data   = "foobartar";
        my $offset = 3;
        my $len    = 3;
        my $real = substr $data, $offset, $len;
        my $b = APR::Bucket->new($data, $offset, $len);
        my $read = $b->read;
        ok t_cmp($real, $read, 'new($data, $offset, $len)');
    }

    # new: offset+ too big len
    {
        my $data   = "foobartar";
        my $offset = 3;
        my $len    = 10;
        my $real = substr $data, $offset, $len;
        my $b = eval { APR::Bucket->new($data, $offset, $len) };
        ok t_cmp(qr/the length argument can't be bigger than the total/,
                 $@,
                 'new($data, $offset, $len_too_big)');
    }

    # remove
    {
        my $b = APR::Bucket->new("aaa");
        # remove $b when it's not attached to anything (not sure if
        # that should be an error)
        $b->remove;
        ok 1;

        # real remove from bb is tested in many other filter tests
    }


    # eos_create / type / length
    {
        my $b = APR::Bucket::eos_create($ba);
        my $type = $b->type;
        ok t_cmp('EOS', $type->name, "eos_create");

        ok t_cmp(0, $b->length, "eos b->length");

        # buckets with no data to read should return an empty string
        ok t_cmp("", $b->read, "eos b->read");
    }

    # flush_create
    {
        my $b = APR::Bucket::flush_create($ba);
        my $type = $b->type;
        ok t_cmp('FLUSH', $type->name, "flush_create");

        ok t_cmp(0, $b->length, "flush b->length");
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
        ok t_cmp("d1", $b->read, "d1 bucket");

        $b = $bb->next($b);
        t_debug("is_flush");
        ok $b->is_flush;

        $b = $bb->next($b);
        ok t_cmp("d2", $b->read, "d2 bucket");

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

        ok t_cmp(undef, $bb->first, "no first bucket");
        ok t_cmp(undef, $bb->last,  "no last bucket");

        ## now there is first
        my $b = APR::Bucket->new("bbb");
        $bb->insert_head($b);
        my $b_first = $bb->first;
        ok t_cmp("bbb", $b->read, "first bucket");

        # but there is no prev
        ok t_cmp(undef, $bb->prev($b_first),  "no prev bucket");

        # and no next
        ok t_cmp(undef, $bb->next($b_first),  "no next bucket");
    }

    return Apache::OK;
}

1;
