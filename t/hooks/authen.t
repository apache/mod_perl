use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 4, \&have_lwp;

my $location = "/TestHooks::authen";

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



