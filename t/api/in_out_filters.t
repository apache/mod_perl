use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 1;

my $location = '/TestAPI__in_out_filters';

my $content = join '', 'AA'..'ZZ', 1..99999;

my $expected = lc $content;
my $received = POST_BODY $location, content => $content;

ok $expected eq $received;

