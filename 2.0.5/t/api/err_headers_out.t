use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 6, need 'HTML::HeadParser';

my $location = '/TestAPI__err_headers_out';

{
    # with 2xx responses any of the err_headers_out and headers_out
    # headers make it through

    my $res = GET "$location?200";

    #t_debug $res->as_string;

    ok t_cmp $res->code, 200, "OK";

    ok t_cmp $res->header('X-err_headers_out'), "err_headers_out",
        "X-err_headers_out: made it";

    ok t_cmp $res->header('X-headers_out'), "headers_out",
        "X-headers_out: made it";
}

{
    # with non-2xx responses only the err_headers_out headers make it
    # through. the headers_out do not make it.

    my $res = GET "$location?404";

    #t_debug $res->as_string;

    ok t_cmp $res->code, 404, "not found";

    ok t_cmp $res->header('X-err_headers_out'), "err_headers_out",
        "X-err_headers_out: made it";

    ok !$res->header('X-headers_out');
}

