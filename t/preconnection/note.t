use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my $module = "TestPreConnection::note";
Apache::TestRequest::module($module);
my $config = Apache::Test::config();
my $hostport = Apache::TestRequest::hostport($config);
my $location = "http://$hostport/" . Apache::TestRequest::module2path($module);
my $remote_addr = $config->{vars}->{remote_addr};
t_debug("connecting to $location");
plan tests => 1;

ok t_cmp(
    $remote_addr,
    GET_BODY_ASSERT($location),
    "connection notes");
