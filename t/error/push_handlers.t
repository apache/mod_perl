use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 1;

my $location = "/TestError::push_handlers";
my $expected = "ok";
my $received = GET_BODY $location;

ok t_cmp($expected, $received);
