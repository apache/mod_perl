use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(GET);

plan tests => 2, have_min_module_version CGI => 2.87;

my $url = "/registry/cgi.pl";
my $res = GET $url;

ok t_cmp(
    qr{^text/html},
    $res->header('Content-type'),
    "test 'Content-type header setting"
   );

ok t_cmp(
    '<b>done</b>',
    lc($res->content),
    "test body"
   );
