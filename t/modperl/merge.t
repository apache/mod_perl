use strict;
use warnings FATAL => 'all';

use Apache::TestRequest qw(GET_BODY_ASSERT);
use Apache::Test;
use Apache::TestUtil;

my $module   = 'TestModperl::merge';
Apache::TestRequest::module($module);

my $config   = Apache::Test::config();
my $hostport = Apache::TestRequest::hostport($config);

my $base = "http://$hostport";

# test server-to-container merging (without overrides) for:
#   PerlSetEnv
#   PerlPassEnv
#   PerlSetVar
#   PerlAddVar

my $uri = "$base/merge";
t_debug("connecting to $uri");
print GET_BODY_ASSERT $uri;
