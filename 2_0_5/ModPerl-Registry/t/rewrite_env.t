use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(GET);

plan tests => 1, need [qw(mod_alias.c mod_rewrite.c)];

{
    my $url = "/rewritetest";
    my $res = GET $url;

    ok t_cmp($res->content(),
             "GOTCHA",
             'found environment variable from mod_rewrite');
}
