use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

# XXX: skip untill the LEAVE problem is fixed in 5.8.1 
plan tests => 1, 0;

my $expected = "[<foo][bar>][<who][ah>]";
my $location = '/TestAPI__rflush';
my $response = GET_BODY $location;
ok t_cmp($expected, $response, "rflush creates bucket brigades");
