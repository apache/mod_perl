use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 1;

my $location = "/TestHooks::stacked_handlers";
my $expected = join "\n", qw(one two three), '';
my $received = GET_BODY $location;

ok t_cmp($expected, $received, "stacked_handlers");
