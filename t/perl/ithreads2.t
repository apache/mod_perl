# perl/ithreads is a similar test but is running from the global perl
# interpreter pool. whereas this test is running against a
# virtual host with its own perl interpreter pool (+Parent)

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest 'GET_BODY_ASSERT';

my $module = 'TestPerl::ithreads';
my $config = Apache::Test::config();
my $path = Apache::TestRequest::module2path($module);

Apache::TestRequest::module($module);
my $hostport = Apache::TestRequest::hostport($config);

t_debug("connecting to $hostport");
print GET_BODY_ASSERT "http://$hostport/$path";
