use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 3;

my $location = "/TestApache::send_cgi_header";
my $res = GET $location;

ok t_cmp('X-Bar',
         $res->header('X-Foo'),
         "header test");

ok t_cmp('Bad Programmer, No cookie!',
         $res->header('Set-Cookie'),
         "header test2");

ok t_cmp("This not the end of the world\n",
         $res->content,
         "body test");
