use Apache::TestUtil;
use Apache::TestRequest 'GET_BODY_ASSERT';

my $config = Apache::Test::config();
my $vars = $config->{vars};

my $module = 'TestVhost::log';
my $url    = Apache::TestRequest::module2url($module);

t_debug("connecting to $url");
print GET_BODY_ASSERT $url;

