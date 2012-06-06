package TestAPRlib::status;

# Testing APR::Status

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use APR::Const -compile => qw(EAGAIN ENOPOLL);
use APR::Status ();

sub num_of_tests {
    return 2;
}

sub test {
    ok APR::Status::is_EAGAIN(APR::Const::EAGAIN);
    ok ! APR::Status::is_EAGAIN(APR::Const::ENOPOLL);
}

1;
