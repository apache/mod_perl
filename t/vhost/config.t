# the handler is configured in modperl_extra.pl via
# Apache->server->add_config

use Apache::TestUtil;
use Apache::TestRequest 'GET';

my $config = Apache::Test::config();
my $vars = $config->{vars};

my $module = 'TestVhost::config';
my $path = Apache::TestRequest::module2path($module);

Apache::TestRequest::module($module);
my $hostport = Apache::TestRequest::hostport($config);

t_debug("connecting to $hostport");
my $res = GET "http://$hostport/$path";

if ($res->is_success) {
    print $res->content;
}
else {
    if ($res->code == 404) {
        my $documentroot = $vars->{documentroot};
        die "this test gets its <Location> configuration added via " .
            "$documentroot/vhost/startup.pl, this could be the cause " .
            "of the failure";
    }
    else {
        die "server side has failed (response code: ", $res->code, "),\n",
            "see t/logs/error_log for more details\n";
    }
}
