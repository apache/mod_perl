#!perl -T

use strict;
use warnings FATAL => 'all';
use Apache::Test;

use TestAPRlib::util;

plan tests => TestAPRlib::util::num_of_tests();

TestAPRlib::util::test();
