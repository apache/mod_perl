package TestAPR::finfo;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use TestAPRlib::finfo;

use APR::Finfo ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    my $tests = 2 + TestAPRlib::finfo::num_of_tests();
    plan $r, tests => $tests;

    {
        my $finfo = $r->finfo;
        my $isa = $finfo->isa('APR::Finfo');

        t_debug "\$r->finfo $finfo";
        ok $isa;
    }

    {
        my $pool = $r->finfo->pool;
        my $isa = $pool->isa('APR::Pool');

        t_debug "\$r->finfo->pool $pool";
        ok $isa;
    }

    TestAPRlib::finfo::test();

    Apache::OK;
}

1;
