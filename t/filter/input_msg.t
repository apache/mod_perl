use Apache::TestRequest ();
use Apache::Test ();

my $module = 'TestFilter::input_msg';

Apache::TestRequest::scheme('http'); #force http for t/TEST -ssl
Apache::TestRequest::module($module);

my $config = Apache::Test::config();
my $hostport = Apache::TestRequest::hostport($config);
print "connecting to $hostport\n";

print $config->http_raw_get("/input_filter.html");
