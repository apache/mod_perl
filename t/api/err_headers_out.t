use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 3;

my $location = '/TestAPI__err_headers_out';

my $res = GET $location;

#t_debug $res->as_string;

ok t_cmp $res->code, 404, "not found";

ok t_cmp $res->header('X-Survivor'), "err_headers_out",
    "X-Survivor: made it";

ok !$res->header('X-Goner');
