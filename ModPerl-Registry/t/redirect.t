use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(GET_BODY HEAD);

use Apache::TestUtil qw(t_catfile_apache);

plan tests => 4, have_lwp;

# need LWP to handle redirects
my $base_url = "/registry/redirect.pl";

{
    my $redirect_path = "/registry/basic.pl";
    my $url = "$base_url?$redirect_path";
    my $vars = Apache::Test::config()->{vars};
    my $script_file = t_catfile_apache $vars->{serverroot}, 'cgi-bin', 'basic.pl';

    ok t_cmp(
        "ok $script_file",
        GET_BODY($url),
        "test redirect: existing target",
       );
}

{
    my $redirect_path = "/registry/does_not_exists.pl";
    my $url = "$base_url?$redirect_path";
    t_client_log_error_is_expected();
    ok t_cmp(
        404,
        HEAD($url)->code,
        "test redirect: non-existing target",
       );
}

{
    local $Apache::TestRequest::RedirectOK = 0;

    my $base_url = "/registry/redirect-cookie.pl";
    my $redirect_path = "/registry/basic.pl";
    my $url = "$base_url?$redirect_path";

    my $response = HEAD $url;

    ok t_cmp(
        302,
        $response->code,
        "test Registry style redirect: status",
       );

    ok t_cmp(
        "mod_perl=ubercool; path=/",
        $response->header('Set-Cookie'),
        "test Registry style redirect: cookie",
       );
}

