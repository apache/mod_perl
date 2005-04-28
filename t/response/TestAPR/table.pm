package TestAPR::table;

# testing APR::Table API

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache2::Const -compile => 'OK';

use TestAPRlib::table;

sub handler {
    my $r = shift;

    # this buffers the ok's and will flush them out on sub's end
    my $x = Apache::TestToStringRequest->new($r);

    my $tests = TestAPRlib::table::num_of_tests();
    plan tests => $tests;

    TestAPRlib::table::test();

    Apache2::Const::OK;
}

1;
