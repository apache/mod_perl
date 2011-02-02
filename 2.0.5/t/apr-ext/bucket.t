#!perl -T

use strict;
use warnings FATAL => 'all';
use Apache::Test;

use TestAPRlib::bucket;

plan tests => TestAPRlib::bucket::num_of_tests();

TestAPRlib::bucket::test();
