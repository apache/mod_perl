# this test tests PerlRequire configuration directive
########################################################################

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my $module = 'TestDirective::perlmodule';

plan tests => 1;

Apache::TestRequest::module($module);

my $config   = Apache::Test::config();
my $hostport = Apache::TestRequest::hostport($config);
my $path = Apache::TestRequest::module2path($module);
t_debug("connecting to $hostport");

ok t_cmp($module,
         GET_BODY("/$path"),
         "testing PerlModule in $module");

