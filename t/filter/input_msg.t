use Apache::TestRequest ();
use Apache::TestConfig ();

my $module = 'TestFilter::input_msg';

Apache::TestRequest::scheme('http'); #force http for t/TEST -ssl
Apache::TestRequest::module($module);

my $config = Apache::TestConfig->thaw;
my $hostport = Apache::TestRequest::hostport($config);
print "connecting to $hostport\n";

print $config->http_raw_get("/input_filter.html");
