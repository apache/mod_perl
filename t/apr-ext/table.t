use strict;
use warnings FATAL => 'all';
use Apache::Test;

use TestAPRlib::table;

plan tests => TestAPRlib::table::number();

TestAPRlib::table::test();
