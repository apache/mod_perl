use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my $module = "TestModperl::perl_options";
my $path = Apache::TestRequest::module2path($module);

Apache::TestRequest::module($module);
my $hostport = Apache::TestRequest::hostport(Apache::Test::config());
my $location = "http://$hostport/$path";

t_debug "connecting to $hostport";
print GET_BODY_ASSERT $location;
