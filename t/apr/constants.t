use ExtUtils::testlib;
use strict;
use warnings FATAL => 'all';

use Test;

use APR::Const -compile => qw(:common POLLIN);
use APR::Const qw(:hook);

plan tests => 4;

ok ! defined &POLLIN;
ok APR::SUCCESS == 0;
ok APR::POLLIN == 0x001;
ok HOOK_LAST == 20;
