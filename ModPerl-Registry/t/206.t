use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(GET);

plan tests => 2;

my $url = "/registry/206.pl";
my $res = GET($url);
my $body = '<?xml versi';

ok t_cmp(
    206,
    $res->code,
    "test partial_content: response code",
);

ok t_cmp(
    $body,
    $res->content,
    "test partial_content: response body",
);
