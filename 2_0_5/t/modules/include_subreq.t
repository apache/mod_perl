use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

my $module = 'TestModules::include_subreq';
my $location = '/' . Apache::TestRequest::module2path($module);

plan tests => 1, ['include'];

my($res, $str);

my $expected = "subreq is quite ok";
my $received = GET_BODY_ASSERT "$location/one";
ok t_cmp($received, $expected, "handler => filter => handler");

