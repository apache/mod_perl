use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 4, need need_lwp, need_auth, 'HTML::HeadParser';

my $location = "/TestHooks__authen_basic";

sok {
    ! GET_OK $location;
};

sok {
    my $rc = GET_RC $location;
    $rc == 401;
};

sok {
    GET_OK $location, username => 'dougm', password => 'foo';
};

sok {
    ! GET_OK $location, username => 'dougm', password => 'wrong';
};



