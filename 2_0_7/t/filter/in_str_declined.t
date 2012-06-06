use strict;
use warnings FATAL => 'all';

use Apache::TestRequest 'POST_BODY_ASSERT';;

my $location = '/TestFilter__in_str_declined';

my $chunk = "1234567890";
my $data = $chunk x 2000;

print POST_BODY_ASSERT $location, content => $data;
