use Apache::TestRequest ();
use Apache::TestConfig ();

my $module = 'TestFilter::input_msg';

local $Apache::TestRequest::Module = $module;
$Apache::TestRequest::Module ||= $module; #-w

my $config = Apache::TestConfig->thaw;
my $hostport = Apache::TestRequest::hostport($config);
print "connecting to $hostport\n";

print $config->http_raw_get("/input_filter.html");
