#!perl -T

use strict;
use warnings FATAL => 'all';
use Apache::Test;

use TestAPRlib::brigade;

plan tests => TestAPRlib::brigade::num_of_tests();

TestAPRlib::brigade::test();
