use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 1, need_lwp && need_auth;

my $location = "/TestCompat__conn_authen";

ok GET_OK $location, username => 'dougm', password => 'foo';

