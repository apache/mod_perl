use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(GET_BODY HEAD);

plan tests => 1;

my $url = "/error_document/cannot_be_found";

{
    my $response = "Oops, can't find the requested doc";
    ok t_cmp(
        $response,
        GET_BODY($url),
        "test ErrorDocument",
       );
}
