use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 4, need need_lwp, need_auth, need_module('Digest::MD5');

my $location = "/TestHooks__authen_digest";

sok {
    ! GET_OK $location;
};

sok {
    my $rc = GET_RC $location;
    $rc == 401;
};

sok {
    GET_OK $location, username => 'Joe', password => 'Smith';
};

sok {
    ! GET_OK $location, username => 'Joe', password => 'SMITH';
};

