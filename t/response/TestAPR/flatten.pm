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

    plan $r, tests => 20;

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

    ok t_cmp($@,
             qr!usage: \$bb->flatten\(\$buf, \[\$wanted\]\)!,
             'APR::Brigade::flatten() requires a brigade');

    # flatten() will slurp up the entire brigade
    # equivalent to calling apr_brigade_pflatten
    {
        my $len = $bb->flatten(my $data);

        verify(200000, $len, $data, 1);
    }

    # flatten(0) returns 0 bytes
    {
        my $len = $bb->flatten(my $data, 0);

        t_debug('$bb->flatten(0) returns a defined value');
        ok (defined $data);

        verify(0, $len, $data, 0);
    }


    # flatten($length) will return the first $length bytes
    # equivalent to calling apr_brigade_flatten
    {
        # small
        my $len = $bb->flatten(my $data, 30);
        verify(30, $len, $data, 1);
    }

    {
        # large
        my $len = $bb->flatten(my $data, 190000);
        verify(190000, $len, $data, 1);
    }

    {
        # more than enough
        my $len = $bb->flatten(my $data, 300000);
        verify(200000, $len, $data, 1);
    }

    # fetch from a brigade with no data in it
    {
        my $len = APR::Brigade->new($pool, $ba)->flatten(my $data);

        t_debug('empty brigade returns a defined value');
        ok (defined $data);

        verify(0, $len, $data, 0);
    }

    Apache::OK;
}

sub verify {
    my($expected_len, $len, $data, $check_content) = @_;

    ok t_cmp($expected_len,
             $len,
             "\$bb->flatten(\$data, $len) returned $len bytes");
    ok t_cmp($len,
             length($data),
             "\$bb->flatten(\$data, $len) returned all expected data");

    if ($check_content) {
        # don't use t_cmp() here, else we get 200,000 characters
        # to look at in verbose mode
        t_debug("data all 'x' characters");
        ok ($data !~ m/[^x]/);
    }

}


1;
