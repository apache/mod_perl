package TestAPRlib::error;

# testing APR::Error API

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use APR::Error;

sub num_of_tests {
    return 1;
}

sub test {
    ok 1;
}

1;
