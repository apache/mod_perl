package TestAPR::uri;

# Testing APR::URI (more tests in TestAPI::uri)

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use Apache2::Const -compile => 'OK';

use TestAPRlib::uri;

sub handler {
    my $r = shift;

    my $num_of_tests = TestAPRlib::uri::num_of_tests();
    plan $r, tests => $num_of_tests;

    TestAPRlib::uri::test();

    Apache2::Const::OK;
}



1;
