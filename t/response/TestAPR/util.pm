package TestAPR::util;

# test APR::Util

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use Apache::Const -compile => 'OK';

use TestAPRlib::util;

sub handler {
    my $r = shift;

    my $num_of_tests = TestAPRlib::util::num_of_tests();
    plan $r, tests => $num_of_tests;

    TestAPRlib::util::test();

    Apache::OK;
}

1;
