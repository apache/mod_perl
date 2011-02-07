use strict;
use warnings FATAL => 'all';

use Apache::TestRequest qw(GET_BODY_ASSERT);
use Apache::Test;
use Apache::TestUtil;

my $module = 'TestHooks::init';

Apache::TestRequest::module($module);
my $path     = Apache::TestRequest::module2path($module);
my $config   = Apache::Test::config();
my $hostport = Apache::TestRequest::hostport($config);
t_debug("connecting to $hostport");

print GET_BODY_ASSERT "http://$hostport/$path";
