#!perl -T

use strict;
use warnings FATAL => 'all';
use Apache::Test;

use TestAPRlib::date;

plan tests => TestAPRlib::date::num_of_tests();

TestAPRlib::date::test();
