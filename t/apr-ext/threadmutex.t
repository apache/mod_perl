use strict;
use warnings FATAL => 'all';
use Apache::Test;

use TestAPRlib::threadmutex;

plan tests => TestAPRlib::threadmutex::num_of_tests();

TestAPRlib::threadmutex::test();
