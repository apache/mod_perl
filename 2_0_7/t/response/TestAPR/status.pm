package TestAPR::status;

# Testing APR::Status

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use Apache2::Const -compile => 'OK';

use TestAPRlib::status;

sub handler {
    my $r = shift;

    my $num_of_tests = TestAPRlib::status::num_of_tests();
    plan $r, tests => $num_of_tests;

    TestAPRlib::status::test();

    Apache2::Const::OK;
}



1;
