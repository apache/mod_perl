use strict;
use warnings FATAL => 'all';

# force use of Apache:TestClient, which doesn't
# require us to set a port in the URI
BEGIN { $ENV{APACHE_TEST_PRETEND_NO_LWP} = 1 }

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 4;

{
    Apache::TestRequest::module("TestHooks::default_port");

    my $uri = '/TestHooks__default_port';
    my $response = GET $uri;
    ok t_cmp(80, $response->content, "$uri, default Apache hook");
}

{
    Apache::TestRequest::module("TestHooks::default_port");

    my $uri = '/TestHooks__default_port';
    my $response = GET "$uri?362";
    ok t_cmp(362, $response->content, "$uri, PerlDefaultPortHandler");
}

{
    Apache::TestRequest::module("TestHooks::default_port2");
    my $hostport = Apache::TestRequest::hostport(Apache::Test::config());
    my $port = (split ':', $hostport)[1];

    my $uri = '/TestHooks__default_port2';
    my $response = GET $uri;
    ok t_cmp($port, $response->content, "$uri, no PerlDefaultHandler configured");
}

{
    Apache::TestRequest::module("TestHooks::default_port3");
    my $hostport = Apache::TestRequest::hostport(Apache::Test::config());
    my $port = (split ':', $hostport)[1];

    my $uri = "http://$hostport/";

    my $response = GET $uri;
    ok t_cmp($port, $response->content, "$uri, no PerlDefaultHandler configured");
}
