use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my $module = 'TestPreConnection::note';
my $url    = Apache::TestRequest::module2url($module);
my $config = Apache::Test::config();

my $remote_addr = $config->{vars}->{remote_addr};
t_debug("connecting to $url");
plan tests => 1;

ok t_cmp(
    GET_BODY_ASSERT($url),
    $remote_addr,
    "connection notes");
