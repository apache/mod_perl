use strict;
use warnings FATAL => 'all';

use Apache::TestRequest;

my $module = "TestDirective::perlloadmodule5";
my $config   = Apache::Test::config();
Apache::TestRequest::module($module);
my $hostport = Apache::TestRequest::hostport($config);

print GET_BODY "http://$hostport/$module";
