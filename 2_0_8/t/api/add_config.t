use strict;
use warnings FATAL => 'all';

use Apache::TestRequest qw(GET_BODY_ASSERT);
use Apache::Test;
use Apache::TestUtil;

my $module = 'TestAPI::add_config';
my $url    = Apache::TestRequest::module2url($module) . "/";

t_debug("connecting to $url");
print GET_BODY_ASSERT $url;

