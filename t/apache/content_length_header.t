use strict;
use warnings FATAL => 'all';

# testing nuances of the HEAD request (e.g. when C-L header makes it
# through)
#
# because apache proclaims itself governor of the C-L header via
# the C-L filter, the important thing to test here is not when
# a C-L header is allowed to pass, but rather whether GET and HEAD
# behave the same wrt C-L under varying circumstances.
# for more discussion on why it is important to get HEAD requests
# right, see these threads from the mod_perl list
#   http://marc.theaimsgroup.com/?l=apache-modperl&m=108647669726915&w=2
#   http://marc.theaimsgroup.com/?t=109122984600001&r=1&w=2
# as well as this bug report from mozilla, which shows how they
# are using HEAD requests in the wild
#   http://bugzilla.mozilla.org/show_bug.cgi?id=245447

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 12 * 2, todo => [2,5];

my $location = "/TestApache__content_length_header";

foreach my $method qw(GET HEAD) {

    no strict qw(refs);

    {
        # if the response handler sends no data, and sets no C-L header,
        # the client doesn't get C-L header
        my $uri = $location;
        my $res = $method->($uri);
        ok t_cmp $res->code, 200, "$method $uri code";
        ok t_cmp $res->header('Content-Length'), undef, "$method $uri C-L header";
        ok t_cmp $res->content, "", "$method $uri content";
    }

    {
        # if the response handler sends no data, and sets C-L header,
        # the client doesn't get C-L header
        my $uri = "$location?set_content_length";
        my $res = $method->($uri);
        ok t_cmp $res->code, 200, "$method $uri code";
        ok t_cmp $res->header('Content-Length'), undef, "$method $uri C-L header";
        ok t_cmp $res->content, "", "$method $uri content";
    }

    {
        # if the response handler sends data, and sets no C-L header,
        # the client doesn't get C-L header
        my $uri = "$location?send_body";
        my $res = $method->($uri);
        ok t_cmp $res->code, 200, "$method $uri code";
        ok t_cmp $res->header('Content-Length'), undef, "$method $uri C-L header";

        my $content = $method eq 'GET' ? 'This is a response string' : '';
        ok t_cmp $res->content, $content, "$method $uri content";
    }

    {
        # if the response handler sends data (e.g. one char string), and
        # sets C-L header, the client gets the C-L header
        my $uri = "$location?send_body+set_content_length";
        my $res = $method->($uri);
        ok t_cmp $res->code, 200, "$method $uri code";
        ok t_cmp $res->header('Content-Length'), 25, "$method $uri C-L header";

        my $content = $method eq 'GET' ? 'This is a response string' : '';
        ok t_cmp $res->content, $content, "$method $uri content";
    }
}
