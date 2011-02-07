#!perl -T

use strict;
use warnings FATAL => 'all';
use Apache::Test;

use TestAPRlib::pool;

plan tests => TestAPRlib::pool::num_of_tests();

TestAPRlib::pool::test();
