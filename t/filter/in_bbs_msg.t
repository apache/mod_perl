use Apache::Test ();
use Apache::TestUtil;

use Apache::TestRequest 'GET';

my $module = 'TestFilter::in_bbs_msg';

Apache::TestRequest::scheme('http'); #force http for t/TEST -ssl
Apache::TestRequest::module($module);

my $config = Apache::Test::config();
my $hostport = Apache::TestRequest::hostport($config);
t_debug("connecting to $hostport");

my $res = GET "http://$hostport/input_filter.html";
if ($res->is_success) {
    print $res->content;
}
else {
    die "server side has failed (response code: ", $res->code, "),\n",
        "see t/logs/error_log for more details\n";
}
