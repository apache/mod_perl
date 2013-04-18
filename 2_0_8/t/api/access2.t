use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 6, need need_lwp, need_auth, need_access, 'HTML::HeadParser';

my $location = "/TestAPI__access2";

ok !GET_OK $location;

my $rc = GET_RC $location;
ok t_cmp $rc, 401, "no credentials passed";

# bad user
ok !GET_OK $location, username => 'root', password => '1234';

# good user/bad pass
ok !GET_OK $location, username => 'goo', password => 'foo';

# good user/good pass
ok GET_OK $location, username => 'goo', password => 'goopass';

# any user/any pass POST works
ok POST_OK $location, username => 'bar', password => 'goopass1',
    content => "a";


