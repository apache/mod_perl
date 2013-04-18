#!perl -T

use strict;
use warnings FATAL => 'all';
use Apache::Test;

use TestAPRlib::os;

plan tests => TestAPRlib::os::num_of_tests();

TestAPRlib::os::test();
