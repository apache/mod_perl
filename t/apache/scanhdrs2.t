use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 5;

my $module = 'TestApache__scanhdrs2';
my $location = "/$module";

my $redirect = 'http://perl.apache.org/';

my $res = GET "$location?$redirect", redirect_ok => 0;

ok t_cmp($redirect, $res->header('Location'),
         "Location header");

ok t_cmp(302, $res->code,
         "status == 302");

$redirect = '/index.html';

$res = GET "$location?$redirect", redirect_ok => 0;

ok t_cmp(1, !$res->header('Location'),
         "no Location header");

ok t_cmp(200, $res->code,
         "status == 200");

ok t_cmp(qr{welcome to}, $res->content,
         "content is index.html");
