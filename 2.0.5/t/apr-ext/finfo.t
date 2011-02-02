#!perl -T

use strict;
use warnings FATAL => 'all';
use Apache::Test;

use TestAPRlib::finfo;

plan tests => TestAPRlib::finfo::num_of_tests();

TestAPRlib::finfo::test();
