use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

#test for mod_include parsing of mod_perl script output
#XXX: needs to be more robust.  see t/htdocs/includes-registry/test.spl
my @patterns = (
    'Perl-SSI', #MY_TEST
    'mod_perl', #SERVER_SOFTWARE
);

plan tests => 2 + @patterns, ['include', 'mod_mime', 'HTML::HeadParser'];

my $location = "/includes-registry/test.spl";

my($res, $str);

$res = GET $location;

ok $res->is_success;

$str = $res->content;

ok $str;

for my $pat (@patterns) {
    ok t_cmp($str, qr{$pat}, "/$pat/");
}
