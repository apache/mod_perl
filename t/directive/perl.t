use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 8, \&have_auth;

#so we don't have to require lwp
my @auth = (Authorization => 'Basic ZG91Z206Zm9v'); #dougm:foo


foreach my $location ("/perl_sections/index.html", 
                      "/perl_sections_readconfig/index.html") {

    sok {
        ! GET_OK $location;
    };

    sok {
        my $rc = GET_RC $location;
        $rc == 401;
    };

    sok {
        GET_OK $location, @auth;
    };

    sok {
        ! GET_OK $location, $auth[0], $auth[1] . 'bogus';
    };
}
