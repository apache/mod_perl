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

    # syntax: require a $bb
    eval { APR::Brigade::flatten("") };

    ok t_cmp(qr!expecting an APR::Brigade derived object!,
             $@,
             'APR::Brigade::flatten() requires a brigade');

    # flatten() will slurp up the entire brigade
    # equivalent to calling apr_brigade_pflatten
    {
        my $data = $bb->flatten();

        ok t_cmp(200000,
                 length($data),
                 '$bb->flatten() returned all the data');

        # don't use t_cmp() here, else we get 200,000 characters
        # to look at in verbose mode
        t_debug("data all 'x' characters");
        ok ($data !~ m/[^x]/);
    }

    # flatten(0) returns 0 bytes
    {
        my $data = $bb->flatten(0);

        t_debug('$bb->flatten(0) returns a defined value');
        ok (defined $data);
    
        ok t_cmp(0,
                 length($data),
                 '$bb->flatten(0) returned no data');
    }


    # flatten($length) will return the first $length bytes
    # equivalent to calling apr_brigade_flatten
    {
        # small
        my $data = $bb->flatten(30);

        ok t_cmp(30,
                 length($data),
                 '$bb->flatten(30) returned 30 characters');

        t_debug("APR::Brigade::flatten() data all 'x' characters");
        ok ($data !~ m/[^x]/);
    }

    {
        # large 
        my $data = $bb->flatten(190000);

        ok t_cmp(190000,
                 length($data),
                 '$bb->flatten(190000) returned 19000 characters');

        t_debug("data all 'x' characters");
        ok ($data !~ m/[^x]/);
    }

    {
        # more than enough
        my $data = $bb->flatten(300000);

        ok t_cmp(200000,
                 length($data),
                 '$bb->flatten(300000) returned all 200000 characters');

        t_debug("data all 'x' characters");
        ok ($data !~ m/[^x]/);
    }

    # fetch from a brigade with no data in it
    {
        my $data = APR::Brigade->new($pool, $ba)->flatten();

        t_debug('empty brigade returns a defined value');
        ok (defined $data);
    
        ok t_cmp(0,
                 length($data),
                 'empty brigade returns data of 0 length');
    }

    Apache::OK;
}

1;
