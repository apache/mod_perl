use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 3, \&have_lwp;

my $location = "/TestModules::cgi";

ok 1;

my $str = GET_BODY "$location?PARAM=2";
print $str;

$str = POST_BODY $location, content => 'PARAM=%33';
print $str;
