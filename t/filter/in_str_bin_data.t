use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 4;

my $base = "/TestFilter__in_str_bin_data";
my @locations = map {$base . $_ } ('', '_filter');
my $expected = "123\001456\000789";

# test the binary data read/print w/ and w/o pass through filter
for my $location (@locations) {
    my $received = POST_BODY_ASSERT $location, content => $expected;

    ok t_cmp(length($expected),
             length($received),
             "$location binary response length");

    ok t_cmp($expected,
             $received,
             "$location binary response data");
}

