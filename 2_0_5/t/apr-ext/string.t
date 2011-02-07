#!perl -T

use strict;
use warnings FATAL => 'all';
use Apache::Test;

use TestAPRlib::string;

plan tests => TestAPRlib::string::num_of_tests();

TestAPRlib::string::test();
