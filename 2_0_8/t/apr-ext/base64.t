#!perl -T

use strict;
use warnings FATAL => 'all';
use Apache::Test;

use TestAPRlib::base64;

plan tests => TestAPRlib::base64::num_of_tests();

TestAPRlib::base64::test();
