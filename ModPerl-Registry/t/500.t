use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(GET);

use constant HAVE_MIN_APACHE_2_0_42 => have_min_apache_version("2.0.42");

my $tests = 5;
$tests += 2 if HAVE_MIN_APACHE_2_0_42;

plan tests => $tests;

{
    # the script changes the status before the run-time error happens,
    # this status change should be ignored
    my $url = "/registry/runtime_error_n_status_change.pl";
    my $res = GET($url);
    #t_debug($res->content);
    ok t_cmp(
        500,
        $res->code,
        "500 error on runtime error (when the script changes the status)",
       );
}

{
    my $url = "/registry/syntax_error.pl";
    my $res = GET($url);
    #t_debug($res->content);
    ok t_cmp(
        500,
        $res->code,
        "500 compile time error (syntax error)",
       );
}

{
    my $url = "/registry/use_error.pl";
    my $res = GET($url);
    #t_debug($res->content);
    ok t_cmp(
        500,
        $res->code,
        "500 compile error on use() failure",
       );
}

{
    my $url = "/registry/missing_headers.pl";
    my $res = GET($url);
    #t_debug($res->content);
    ok t_cmp(
        500,
        $res->code,
        "500 error on missing HTTP headers",
       );
}

{
    # since we have a runtime error before any body is sent, mod_perl
    # has a chance to communicate the return status of the script to
    # Apache before headers are sent, so we get the code 500 in the
    # HTTP headers
    my $url = "/registry/runtime_error.pl";
    my $res = GET($url);
    #t_debug($res->content);
    ok t_cmp(
        500,
        $res->code,
        "500 error on runtime error",
       );
}

# this behavior is specific for 2.0.42+ I think (at least it's still
# different with apache < 2.0.41 (haven't tested with 41, 42, 43))
if (HAVE_MIN_APACHE_2_0_42) {
    # even though we have a runtime error here, the scripts succeeds
    # to send some body before the error happens and since by that
    # time Apache has already sent the headers, they will include 
    # 200 OK
    my $url = "/registry/runtime_error_plus_body.pl";
    my $res = GET($url);
    #t_debug($res->content);
    ok t_cmp(
        200,
        $res->code,
        "200, followed by a runtime error",
       );

    # the error message is attached after the body
    ok t_cmp(
        qr/some body.*The server encountered an internal error/ms,
        $res->content,
        "200, followed by a runtime error",
       );
}
