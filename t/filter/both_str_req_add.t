use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 1, need_min_module_version('B::Deparse', 0.6);

my $data = join ' ', 'A'..'Z', 0..9;
my $expected = lc $data; # that's what the input filter does
$expected =~ s/\s+//g;   # that's what the output filter does
$expected .= "end";      # that's what the anon output filter does
my $location = '/TestFilter__both_str_req_add';
my $response = POST_BODY $location, content => $data;
ok t_cmp($response, $expected, "lc input and reverse output filters");

