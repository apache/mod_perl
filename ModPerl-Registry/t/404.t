use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(GET_BODY GET);

plan tests => 2, need 'mod_alias.c';

{
    t_client_log_error_is_expected();
    my $url = "/error_document/cannot_be_found";
    my $response = "Oops, can't find the requested doc";
    ok t_cmp(
        GET_BODY($url),
        $response,
        "test ErrorDocument"
    );
}


{
    my $url = "/registry/status_change.pl";
    my $res = GET($url);
    ok t_cmp(
        $res->code,
        404,
        "the script has changed the status to 404"
    );
}
