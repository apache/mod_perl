use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my $module = "TestModperl::perl_options";
Apache::TestRequest::module($module);
my $hostport = Apache::TestRequest::hostport(Apache::Test::config());
my $location = "http://$hostport/$module";

print GET_BODY_ASSERT "http://$hostport/$module";
