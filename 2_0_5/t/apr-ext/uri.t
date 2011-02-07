#!perl -T

use strict;
use warnings FATAL => 'all';
use Apache::Test;

use TestAPRlib::uri;

plan tests => TestAPRlib::uri::num_of_tests();

TestAPRlib::uri::test();
