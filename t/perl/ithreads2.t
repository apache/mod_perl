# perl/ithreads is a similar test but is running from the global perl
# interpreter pool. whereas this test is running against a
# virtual host with its own perl interpreter pool (+Parent)

use strict;
use warnings FATAL => 'all';

use Config;

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest 'GET_BODY_ASSERT';

# perl < 5.6.0 fails to compile code with 'shared' attributes, so we must skip
# it here.
unless ($] >= 5.008001 && $Config{useithreads}) {
    plan tests => 1, have 
        {"perl 5.8.1 or higher w/ithreads enabled is required" => 0};
}

my $module = 'TestPerl::ithreads';
my $config = Apache::Test::config();
my $path = Apache::TestRequest::module2path($module);

Apache::TestRequest::module($module);
my $hostport = Apache::TestRequest::hostport($config);

t_debug("connecting to $hostport");
print GET_BODY_ASSERT "http://$hostport/$path";
