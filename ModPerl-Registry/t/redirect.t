use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(GET_BODY HEAD);

plan tests => 2;

my $base_url = "/registry/redirect.pl";

{
    my $redirect_path = "/registry/basic.pl";
    my $url = "$base_url?$redirect_path";

    ok t_cmp(
        "ok",
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
