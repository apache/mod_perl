use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 2;

my $location = "/TestModperl__getc";

my $expect = join '', 'a'..'Z';

my $str = POST_BODY $location, content => $expect;

ok $str;

ok t_cmp($str, $expect, 'getc');

