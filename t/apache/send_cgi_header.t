use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 4;

my $location = "/TestApache__send_cgi_header";
my $res = GET $location;

ok t_cmp('X-Bar',
         $res->header('X-Foo'),
         "header test");

ok t_cmp('Bad Programmer, No cookie!',
         $res->header('Set-Cookie'),
         "header test2");

my $expected = "\0\0This not the end of the world\0\0\n";
my $received = $res->content;

ok t_cmp(length($expected),
         length($received),
         "body length test");

# \000 aren't seen when printed
ok t_cmp($expected,
         $received,
         "body content test");
