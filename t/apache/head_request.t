use strict;
use warnings FATAL => 'all';

# testing nuances of the HEAD request (e.g. when C-L header makes it
# through)

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 12;

my $location = "/TestApache__head_request";

{
    # if the response handler sends no data, and sets no C-L header,
    # the client doesn't get C-L header
    my $res = HEAD "$location";
    ok t_cmp $res->code, 200, "code";
    ok t_cmp $res->header('Content-Length'), undef, "C-L header";
    ok t_cmp $res->content, "", "content";
}

{
    # if the response handler sends no data, and sets C-L header,
    # the client doesn't get C-L header
    my $res = HEAD "$location?set_content_length";
    ok t_cmp $res->code, 200, "code";
    ok t_cmp $res->header('Content-Length'), undef, "C-L header";
    ok t_cmp $res->content, "", "content";
    t_debug $res->as_string;
}

{
    # if the response handler sends data, and sets no C-L header,
    # the client doesn't get C-L header
    my $res = HEAD "$location?send_body";
    ok t_cmp $res->code, 200, "code";
    ok t_cmp $res->header('Content-Length'), undef, "C-L header";
    ok t_cmp $res->content, "", "content";
    t_debug $res->as_string;
}

{
    # if the response handler sends data (e.g. one char string), and
    # sets C-L header, the client gets the C-L header
    my $res = HEAD "$location?send_body+set_content_length";
    ok t_cmp $res->code, 200, "code";
    ok t_cmp $res->header('Content-Length'), 25, "C-L header";
    ok t_cmp $res->content, "", "content";
    t_debug $res->as_string;
}
