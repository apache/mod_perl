use strict;
use warnings FATAL => 'all';

use Apache::TestRequest;
use Apache::Test;

my $module = "TestDirective::perlloadmodule4";
my $config   = Apache::Test::config();
Apache::TestRequest::module($module);
my $hostport = Apache::TestRequest::hostport($config);
my $path = Apache::TestRequest::module2path($module);

print GET_BODY_ASSERT "http://$hostport/$path";
