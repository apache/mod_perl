use strict;
use warnings FATAL => 'all';

# The Cookie HTTP header can be accessed via $r->headers_in and in certain
# situations via $ENV{HTTP_COOKIE}.
#
# in this test we should be able get the cookie via %ENV,
# since 'SetHandler perl-script' sets up mod_cgi env var. Moreover
# adding 'PerlOptions +SetupEnv' adds them at the very first stage used
# by mod_perl handlers, 'access' in this test. the last sub-test makes
# sure, that mod_cgi env vars don't persist and are properly re-set at
# the end of each request
#
# since the test is run against the same interpreter we also test that
# the cookie value doesn't persist if it makes it to %ENV.


use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 3;

my $module   = 'TestModperl::cookie';
my $location = '/' . Apache::TestRequest::module2path($module);

my $cookie = 'foo=bar';
my %cookies = (
     header   => $cookie,
     env      => $cookie,
     nocookie => '',
);

# 'nocookie' must be run last, server-side shouldn't find a cookie
# (testing that %ENV is reset to its original values for vars set by
# $r->subprocess_env, which is run internally for 'perl-script')
# this requires that all the tests are run against the same interpter

my @tests_ordered = qw(header env nocookie);

t_debug "getting the same interp ID for $location";
my $same_interp = Apache::TestRequest::same_interp_tie($location);

my $skip = $same_interp ? 0 : 1;
for my $test (@tests_ordered) {
    my $expected = $test eq 'nocookie' ? '' : "bar";
    my @headers = ();
    push @headers, (Cookie => $cookies{$test}) unless $test eq 'nocookie';

    my $received = get_body($same_interp, \&GET, "$location?$test", @headers);
    $skip++ unless defined $received;
    skip_not_same_interp(
        $skip,
        $expected,
        $received,
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
