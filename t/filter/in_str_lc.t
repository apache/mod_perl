use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 1;

my $location = '/TestFilter::in_str_lc';

my $chunk = "[Foo BaR] ";
my $data = $chunk x 250;
my $expected = lc $data;
my $received = POST_BODY $location, content => $data;

ok t_cmp($expected, $received, "input stream filter lc")

