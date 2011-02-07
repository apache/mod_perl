#!perl -T

use strict;
use warnings FATAL => 'all';
use Apache::Test;

use TestAPRlib::status;

plan tests => TestAPRlib::status::num_of_tests();

TestAPRlib::status::test();
