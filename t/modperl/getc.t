use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 2, \&have_lwp;

my $location = "/TestModperl::getc";

my $expect = join '', 'a'..'Z';

my $str = POST_BODY $location, content => $expect;

ok $str;

ok t_cmp($expect, $str, 'getc');

