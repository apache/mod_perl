use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(GET);

plan tests => 1;

{
    t_client_log_error_is_expected();
    my $url = "/perlrun/r_inherited.pl";
    my $res = GET($url);
    ok t_cmp(
        500,
        $res->code,
        "the script hasn't declared its private \$r",
       );
}
