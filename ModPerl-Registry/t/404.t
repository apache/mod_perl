use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(GET_BODY GET);

plan tests => 2;

{
    my $url = "/error_document/cannot_be_found";
    my $response = "Oops, can't find the requested doc";
    ok t_cmp(
        $response,
        GET_BODY($url),
        "test ErrorDocument",
       );
}


{
    my $url = "/registry/status_change.pl";
    my $res = GET($url);
    ok t_cmp(
        404,
        $res->code,
        "the script has changed the status to 404",
       );
}
