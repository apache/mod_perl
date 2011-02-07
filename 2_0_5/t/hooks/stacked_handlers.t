use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 1;

my $location = "/TestHooks__stacked_handlers";
my $expected = join "\n", qw(one two three), '';
my $received = GET_BODY $location;

ok t_cmp($received, $expected, "stacked_handlers");
