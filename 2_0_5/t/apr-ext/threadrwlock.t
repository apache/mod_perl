#!perl -T

use strict;
use warnings FATAL => 'all';
use Apache::Test;

use TestAPRlib::threadrwlock;

plan tests => TestAPRlib::threadrwlock::num_of_tests(), need_threads;

TestAPRlib::threadrwlock::test();
