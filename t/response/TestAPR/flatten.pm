package TestAPR::flatten;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::RequestRec ();
use APR::Bucket ();
use APR::Brigade ();

use Apache::Const -compile => 'OK';

sub handler {

    my $r = shift;

    plan $r, tests => 14;

    # first, create a brigade
    my $pool = $r->pool;
    my $ba   = $r->connection->bucket_alloc;

    my $bb   = APR::Brigade->new($pool, $ba);

    # now, let's put several buckets in it
    for (1 .. 10) {
        my $data = 'x' x 20000;
        my $bucket = APR::Bucket->new($data);
        $bb->insert_tail($bucket);
    }

    # ok, that's 10 buckets of 20,000 = 200,000 characters
    ok t_cmp(200000,
             $bb->length,
             'APR::Brigade::length()');

    # syntax: always require a pool
    eval { $bb->flatten() };

    ok t_cmp(qr/Usage: APR::Brigade::flatten/,
             $@,
             'APR::Brigade::flatten() requires a pool');

    # flatten($pool) will slurp up the entire brigade
    # equivalent to calling apr_brigade_pflatten
    {
        my $data = $bb->flatten($pool);

        ok t_cmp(200000,
                 length($data),
                 'APR::Brigade::flatten() returned all the data');

        # don't use t_cmp() here, else we get 200,000 characters
        # to look at in verbose mode
        t_debug("APR::Brigade::flatten() data all 'x' characters");
        ok ($data !~ m/[^x]/);
    }

    # syntax: flatten($p, 0) is equivalent to flatten($p)
    {
        my $data = $bb->flatten($pool, 0);

        ok t_cmp(200000,
                 length($data),
                 'APR::Brigade::flatten() returned all the data');

        t_debug("APR::Brigade::flatten() data all 'x' characters");
        ok ($data !~ m/[^x]/);
    }


    # flatten($pool, $length) will return the first $length bytes
    # equivalent to calling apr_brigade_flatten
    {
        # small
        my $data = $bb->flatten($pool, 30);

        ok t_cmp(30,
                 length($data),
                 'APR::Brigade::flatten() returned all the data');

        t_debug("APR::Brigade::flatten() data all 'x' characters");
        ok ($data !~ m/[^x]/);
    }

    {
        # large 
        my $data = $bb->flatten($pool, 190000);

        ok t_cmp(190000,
                 length($data),
                 'APR::Brigade::flatten() returned all the data');

        t_debug("APR::Brigade::flatten() data all 'x' characters");
        ok ($data !~ m/[^x]/);
    }

    {
        # more than enough
        my $data = $bb->flatten($pool, 300000);

        ok t_cmp(200000,
                 length($data),
                 'APR::Brigade::flatten() returned all the data');

        t_debug("APR::Brigade::flatten() data all 'x' characters");
        ok ($data !~ m/[^x]/);
    }

    # fetch from a brigade with no data in it
    {
        my $data = APR::Brigade->new($pool, $ba)->flatten($pool);

        t_debug('an empty brigade returns a defined value');
        ok (defined $data);
    
        ok t_cmp(0,
                 length($data),
                 'an empty brigade returns data of 0 length');
    }

    Apache::OK;
}

1;
