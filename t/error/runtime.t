use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 1;

my $location = "/TestError__runtime";
my $res = GET($location);
#t_debug($res->content);
ok t_cmp(
    500,
    $res->code,
    "500 error on runtime error",
   );
