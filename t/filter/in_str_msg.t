use Apache::TestRequest;
use Apache::Test ();
use Apache::TestUtil;

my $module = 'TestFilter::in_str_msg';

Apache::TestRequest::scheme('http'); #force http for t/TEST -ssl
Apache::TestRequest::module($module);

my $config = Apache::Test::config();
my $hostport = Apache::TestRequest::hostport($config);
t_debug("connecting to $hostport");

print GET_BODY("/input_filter.html");
