use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::TestRequest;

my $location = "/TestModules__proxy";

plan tests => 1, (need_module('proxy') &&
                  need_access);

my $expected = "ok";
my $received = GET_BODY_ASSERT $location;
ok t_cmp($received, $expected, "internally proxified request");
