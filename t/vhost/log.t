use Apache::TestUtil;
use Apache::TestRequest 'GET_BODY_ASSERT';

my $config = Apache::Test::config();
my $vars = $config->{vars};

my $module = 'TestVhost::log';
my $path = Apache::TestRequest::module2path($module);

Apache::TestRequest::module($module);
my $hostport = Apache::TestRequest::hostport($config);

t_debug("connecting to $hostport");
print GET_BODY_ASSERT "http://$hostport/$path";

