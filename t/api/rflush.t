use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 1;

my $expected = "[<foo][bar>][<who][ah>]";
my $location = '/TestAPI__rflush';
my $response = GET_BODY $location;
ok t_cmp($expected, $response, "rflush creates bucket brigades");
