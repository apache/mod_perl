use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my $module = 'TestModules::proxy';
my $url    = Apache::TestRequest::module2url($module);

t_debug("connecting to $url");

plan tests => 1, (need_module('proxy') &&
                  need_access);

my $expected = "ok";
my $received = GET_BODY_ASSERT $url;
ok t_cmp($received, $expected, "internally proxified request");
