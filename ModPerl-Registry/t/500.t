use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(GET);

plan tests => 2;


{
    my $url = "/registry/syntax_error.pl";
    my $res = GET($url);
    t_debug($res->content);
    ok t_cmp(
        500,
        $res->code,
        "500 error on syntax error",
       );
}

{
    my $url = "/registry/missing_headers.pl";
    my $res = GET($url);
    t_debug($res->content);
    ok t_cmp(
        500,
        $res->code,
        "500 error on missing HTTP headers",
       );
}
