use strict;
use warnings FATAL => 'all';

use Apache::Test ();
use Apache::TestUtil;

use Apache::TestRequest;

my $module = 'TestFilter::in_bbs_inject_header';
my $location = "/" . Apache::TestRequest::module2path($module);

Apache::TestRequest::scheme('http'); #force http for t/TEST -ssl
Apache::TestRequest::module($module);

my $config = Apache::Test::config();
my $hostport = Apache::TestRequest::hostport($config);
my $content = "This body shouldn't be seen by the filter";
t_debug("connecting to $hostport");

print POST_BODY_ASSERT $location, content => $content;
