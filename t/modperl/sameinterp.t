use strict;
use warnings FATAL => 'all';

# run tests through the same interpreter, even if the server is
# running more than one

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

use TestCommon::SameInterp;

plan tests => 12, need 'HTML::HeadParser';

my $url = "/TestModperl__sameinterp";

# test the tie and re-tie
for (1..2) {
    my $same_interp = Apache::TestRequest::same_interp_tie($url);
    ok $same_interp;

    my $expected = 1;
    my $skip  = 0;
    # test GET over the same same_interp
    for (1..2) {
        $expected++;
        my $res = same_interp_req($same_interp, \&GET, $url, foo => 'bar');
        $skip++ unless defined $res;
        same_interp_skip_not_found(
            $skip,
            defined $res && $res->content,
            $expected,
            "GET over the same interp"
        );
    }
}

{
    # test POST over the same same_interp
    my $same_interp = Apache::TestRequest::same_interp_tie($url);
    ok $same_interp;

    my $expected = 1;
    my $skip  = 0;
    for (1..2) {
        $expected++;
        my $content = join ' ', 'ok', $_ + 3;
        my $res = same_interp_req($same_interp, \&POST, $url,
            content => $content);
        $skip++ unless defined $res;
        same_interp_skip_not_found(
            $skip,
            defined $res && $res->content,
            $expected,
            "POST over the same interp"
        );
    }
}

{
    # test HEAD over the same same_interp
    my $same_interp = Apache::TestRequest::same_interp_tie($url);
    ok $same_interp;

    my $expected = 1;
    my $skip  = 0;
    for (1..2) {
        $expected++;
        my $res = same_interp_req($same_interp, \&HEAD, $url);
        $skip++ unless defined $res;
        same_interp_skip_not_found(
            $skip,
            defined $res && $res->header(Apache::TestRequest::INTERP_KEY),
            $same_interp,
            "HEAD over the same interp"
        );
    }
}
