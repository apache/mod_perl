package TestAPR::finfo;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::RequestRec ();
use Apache::RequestIO ();

use TestAPRlib::finfo;

use APR::Finfo ();

use Apache::Const -compile => 'OK';
use APR::Const    -compile => qw(FINFO_NORM);

sub handler {
    my $r = shift;

    my $tests = 3 + TestAPRlib::finfo::num_of_tests();
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

    {
        my $finfo = APR::Finfo::stat(__FILE__, APR::FINFO_NORM, $r->pool);
        t_debug "\$r->finfo(\$finfo)";
        $r->finfo($finfo);
        ok $r->finfo->fname;
    }

    TestAPRlib::finfo::test();

    Apache::OK;
}

1;
