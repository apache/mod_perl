use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 1;

my $location = '/TestFilter::in_str_sandwich';

my $expected = join "\n", qw(HEADER BODY TAIL), '';
my $received = POST_BODY $location, content => "BODY\n";

ok t_cmp($expected, $received, "input stream filter sandwich")

