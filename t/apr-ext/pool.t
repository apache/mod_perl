#!perl -T

use strict;
use warnings FATAL => 'all';

#use threads;

use TestAPRlib::pool;

use Apache::Test;

plan tests => TestAPRlib::pool::num_of_tests();

TestAPRlib::pool::test();

