#!perl -T

use strict;
use warnings FATAL => 'all';
use Test::More ();
use Apache::Test;

use TestAPRlib::table;

plan tests => TestAPRlib::table::num_of_tests();

TestAPRlib::table::test();
