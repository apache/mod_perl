#!perl -T

use strict;
use warnings FATAL => 'all';
use Apache::Test;

use TestAPRlib::error;

plan tests => TestAPRlib::error::num_of_tests();

TestAPRlib::error::test();
