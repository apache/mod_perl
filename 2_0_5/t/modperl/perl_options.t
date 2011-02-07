use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my $module = 'TestModperl::perl_options';
my $url    = Apache::TestRequest::module2url($module);

t_debug "connecting to $url";
print GET_BODY_ASSERT $url;
