use strict;
use warnings FATAL => 'all';

# run tests through the same interpreter, even if the server is
# running more than one

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 12;

my $url = "/TestModperl::sameinterp";

# test the tie and re-tie
for (1..2) {
    my $same_interp = Apache::TestRequest::same_interp_tie($url);
    ok $same_interp;

    my $value = 1;
    # test GET over the same same_interp
    for (1..2) {
        $value++;
        my $res = Apache::TestRequest::same_interp_do($same_interp, \&GET,
                                                      $url, foo => 'bar');
        ok t_cmp(
            $value,
            defined $res && $res->content,
            "GET over the same interp");
    }
}

{
    # test POST over the same same_interp
    my $same_interp = Apache::TestRequest::same_interp_tie($url);
    ok $same_interp;

    my $value = 1;
    for (1..2) {
        $value++;
        my $content = join ' ', 'ok', $_ + 3;
        my $res = Apache::TestRequest::same_interp_do($same_interp, \&POST,
                                                      $url,
                                                      content => $content);
        ok t_cmp(
            $value,
            defined $res && $res->content,
            "POST over the same interp");
    }
}

{
    # test HEAD over the same same_interp
    my $same_interp = Apache::TestRequest::same_interp_tie($url);
    ok $same_interp;

    my $value = 1;
    for (1..2) {
        $value++;
        my $res = Apache::TestRequest::same_interp_do($same_interp, \&HEAD,
                                                      $url);
        ok t_cmp(
            $same_interp,
            defined $res && $res->header(Apache::TestRequest::INTERP_KEY),
            "HEAD over the same interp");
    }
}
