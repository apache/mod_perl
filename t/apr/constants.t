use ExtUtils::testlib;
use strict;
use warnings FATAL => 'all';

use Apache::Test;

use Apache::TestUtil;

use APR::Const -compile => qw(:common POLLIN :filetype);
use APR::Const qw(:hook);

plan tests => 5;

ok ! defined &POLLIN;
ok t_cmp (APR::SUCCESS, 0, 'APR::SUCCESS');
ok t_cmp (APR::POLLIN, 0x001, 'APR::POLLIN');
ok t_cmp (HOOK_LAST, 20, 'HOOK_LAST');
ok t_cmp (APR::FILETYPE_UNKFILE, 127, 'APR::UNKFILE');
