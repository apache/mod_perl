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

    plan $r, tests => 9;

    # first, create a brigade
    my $bb = APR::Brigade->new($r->pool, 
                               $r->connection->bucket_alloc);

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

    # slurp up the entire brigade
    # this is somewhat wasteful, since we're simulating a user
    # 'guessing' at how much data there is to slurp
    {
        my $rc = $bb->flatten(my $data, my $length = 300000);

        ok t_cmp(APR::SUCCESS,
                 $rc,
                 'APR::Brigade::flatten() return value');

        ok t_cmp(200000,
                 $length,
                 'APR::Brigade::flatten() length population');

        ok t_cmp(200000,
                 length($data),
                 'APR::Brigade::flatten() returned all the data');

        # don't use t_cmp() here, else we get 200,000 characters
        # to look at in verbose mode
        t_debug("APR::Brigade::flatten() data all 'x' characters");
        ok ($data !~ m/[^x]/);
    }

    # test that other length variants - such as constants and
    # subroutine returns - don't segfault
    {
        my $rc = $bb->flatten(my $data, 300000);

        ok t_cmp(APR::SUCCESS,
             $rc,
             'APR::Brigade::flatten() return value');
    }

    # this is probably the best example of using flatten() to
    # get the entire brigade - using $bb->length to determine 
    # the full size of the brigade.
    # probably still inefficient, though...
    {
        my $rc = $bb->flatten(my $data, $bb->length);

        ok t_cmp(APR::SUCCESS,
             $rc,
             'APR::Brigade::flatten() return value');
    }

    # this is the most proper use of flatten() - retrieving
    # only a chunk of a brigade.  most examples in httpd core
    # use flatten() to grab the first 30 bytes or so
    {
        my $rc = $bb->flatten(my $data, 100000);

        ok t_cmp(APR::SUCCESS,
             $rc,
             'APR::Brigade::flatten() return value');

        ok t_cmp(100000,
                 length($data),
                 'APR::Brigade::flatten() returned all the data');
    }

    # pflatten() examples to come...

    Apache::OK;
}

1;
