use strict;
use warnings FATAL => 'all';

use Apache::TestUtil;
use Apache::Test;
use Apache::TestRequest;

my $location = "/TestApache__discard_rbody";
my $content = "Y" x 100000; # more than one bucket

plan tests => 3;

for my $test (qw(none partial all)) {
    my $received = POST_BODY "$location?$test", content => $content;
    ok t_cmp($test, $received, "data consumption: $test");
}

