use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

use Apache2 ();
use Apache2::Const ':common';

my $module = 'TestHooks::trans';
Apache::TestRequest::module($module);
my $path     = Apache::TestRequest::module2path($module);
my $config   = Apache::Test::config();
my $hostport = Apache::TestRequest::hostport($config);
t_debug("connecting to $hostport");

plan tests => 3;

t_client_log_error_is_expected();
ok t_cmp GET_RC("http://$hostport/nope"), NOT_FOUND;

my $body = GET_BODY "http://$hostport/TestHooks/trans.pm";

ok $body =~ /package $module/;

ok GET_OK "http://$hostport/phooey";
