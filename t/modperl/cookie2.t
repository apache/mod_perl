use strict;
use warnings FATAL => 'all';

# The Cookie HTTP header can be accessed via $r->headers_in and in certain
# situations via $ENV{HTTP_COOKIE}.
#
# in this test we shouldn't be able get the cookie via %ENV,
# since 'SetHandler modperl' doesn't set up CGI env var. unless the
# handler calls "$r->subprocess_env" by itself
#
# since the test is run against the same interpreter we also test that
# the cookie value doesn't persist if it makes it to %ENV.

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;
use TestCommon::SameInterp;

plan tests => 3, need 'HTML::HeadParser';

my $module   = 'TestModperl::cookie2';
my $location = '/' . Apache::TestRequest::module2path($module);

my %expected =
(
    header         => "header",
    subprocess_env => "subprocess_env",
    env            => '',
);

my @tests_ordered = qw(header subprocess_env env);

t_debug "getting the same interp ID for $location";
my $same_interp = Apache::TestRequest::same_interp_tie($location);

my $skip = $same_interp ? 0 : 1;
for my $test (@tests_ordered) {
    my $cookie = "key=$test";

    my $received = same_interp_req_body($same_interp, \&GET,
                                        "$location?$test",
                                        Cookie => $cookie);
    $skip++ unless defined $received;
    same_interp_skip_not_found(
        $skip,
        $received,
        $expected{$test},
        "perl-script+SetupEnv/cookie: $test"
    );
}
