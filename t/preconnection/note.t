use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my $module = "TestPreConnection::note";
Apache::TestRequest::module($module);
my $hostport = Apache::TestRequest::hostport(Apache::Test::config());
my $location = "http://$hostport/" . Apache::TestRequest::module2path($module);
t_debug("connecting to $location");
plan tests => 1;

ok t_cmp(
    'ok', 
    GET_BODY($location),
    "connection notes");
