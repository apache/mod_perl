use strict;
use warnings FATAL => 'all';

use Test;
use Apache::TestRequest;

plan tests => 4;

my $location = "/TestHooks::authen";

ok ! GET_OK $location;

my $rc = GET_RC $location;

ok $rc == 401;

ok GET_OK $location, username => 'dougm', password => 'foo';

ok ! GET_OK $location, username => 'dougm', password => 'wrong';


