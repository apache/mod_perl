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

plan tests => 3;

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

    my $received = get_body($same_interp, \&GET,
                            "$location?$test", Cookie => $cookie);
    $skip++ unless defined $received;
    skip_not_same_interp(
        $skip,
        $received,
        $expected{$test},
        "perl-script+SetupEnv/cookie: $test"
    );
}

# if we fail to find the same interpreter, return undef (this is not
# an error)
sub get_body {
    my $res = eval {
        Apache::TestRequest::same_interp_do(@_);
    };
    return undef if $@ =~ /unable to find interp/;
    return $res->content if $res;
    die $@ if $@;
}

# make the tests resistant to a failure of finding the same perl
# interpreter, which happens randomly and not an error.
# the first argument is used to decide whether to skip the sub-test,
# the rest of the arguments are passed to 'ok t_cmp';
sub skip_not_same_interp {
    my $skip_cond = shift;
    if ($skip_cond) {
        skip "Skip couldn't find the same interpreter", 0;
    }
    else {
        my($package, $filename, $line) = caller;
        # trick ok() into reporting the caller filename/line when a
        # sub-test fails in sok()
        return eval <<EOE;
#line $line $filename
    ok &t_cmp;
EOE
    }
}
