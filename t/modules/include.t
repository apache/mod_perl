use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

#test for mod_include include virtual of a mod_perl script
my @patterns = (
    'mod_perl mod_include test',
    'Hello World',
    'cgi.pm',
    'footer',
);

plan tests => 2 + @patterns, ['include', 'CGI'];

my $location = "/includes/test.shtml";


my($res, $str);

$res = GET $location;

ok $res->is_success;

$str = $res->content;

ok $str;

for my $pat (@patterns) {
    ok t_cmp($str, qr{$pat}, "/$pat/");
}
