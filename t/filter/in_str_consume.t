use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 1;

my $location = '/TestFilter::in_str_consume';

# send a message bigger than 8k, so to make sure that the input filter
# will get more than one bucket brigade with data.
my $data = "A 22 chars long string" x 500; # about 11k
my $received = POST_BODY $location, content => $data;
my $expected = "read just the first 1024b from the first brigade";

ok t_cmp($expected, $received, "input stream filter partial consume")
