use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 1;

my $location = '/TestFilter__in_bbs_underrun';

# send a message bigger than 8k, so to make sure that the input filter
# will get more than one bucket brigade with data.
my $length = 40 * 1024 + 7; # ~40k (~5 incoming bucket brigades)
my $data = "x" x $length;
my $received = POST_BODY $location, content => $data;
my $expected = "read $length chars";

ok t_cmp($expected, $received, "input stream filter underrun test")
