use Apache::Test ();
use Apache::TestUtil;

use Apache::TestRequest 'GET_BODY_ASSERT';

my $module = 'TestFilter::in_bbs_msg';

Apache::TestRequest::scheme('http'); #force http for t/TEST -ssl
Apache::TestRequest::module($module);

my $config = Apache::Test::config();
my $hostport = Apache::TestRequest::hostport($config);
t_debug("connecting to $hostport");

print GET_BODY_ASSERT "/input_filter.html";
