use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(GET);

plan tests => 2, need [qw(mod_alias.c HTML::HeadParser)];

my $url = "/registry/206.pl";
my $res = GET($url);
my $body = '<?xml versi';

ok t_cmp(
    $res->code,
    206,
    "test partial_content: response code",
);

ok t_cmp(
    $res->content,
    $body,
    "test partial_content: response body",
);
