use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(GET);

plan tests => 4;

my $url = "/registry/304.pl";

{
    # not modified
    my $if_modified_since = 'Sun, 29 Oct 2000 15:55:00 GMT';
    my $res = GET($url, 'If-Modified-Since' => $if_modified_since);

    ok t_cmp(
        304,
        $res->code,
        "test HTTP_NOT_MODIFIED (304 status)",
    );

    ok t_cmp(
        '',
        $res->content,
        "test HTTP_NOT_MODIFIED (null body)",
    );

    #t_debug $res->as_string;
}


{
    # modified
    my $if_modified_since = 'Sun, 29 Oct 2000 15:43:28 GMT';
    my $res = GET($url, 'If-Modified-Since' => $if_modified_since);

    ok t_cmp(
        200,
        $res->code,
        "test !HTTP_NOT_MODIFIED (200 status)",
    );

    ok t_cmp(
        '<html><head></head><body>Test</body></html>',
        $res->content,
        "test !HTTP_NOT_MODIFIED (normal body)",
    );

    #t_debug $res->as_string;
}
