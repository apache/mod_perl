use ExtUtils::testlib;
use strict;
use warnings FATAL => 'all';

use Test;

use Apache2 ();
use Apache::TestUtil;

use APR::Const -compile => qw(:common POLLIN :filetype);
use APR::Const qw(:hook);

plan tests => 5;

ok ! defined &POLLIN;
ok t_cmp (0, APR::SUCCESS, 'APR::SUCCESS');
ok t_cmp (0x001, APR::POLLIN, 'APR::POLLIN');
ok t_cmp (20, HOOK_LAST, 'HOOK_LAST');
ok t_cmp (127, APR::UNKFILE, 'APR::UNKFILE');
