use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 2;

my $location = "/TestModperl::readline";

my $expect = join "\n", map { $_ x 24 } 'a'..'e';

my $str = POST_BODY $location, content => $expect;

ok $str;

ok t_cmp($expect, $str, 'readline');

