use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 2;

my $location = '/TestFilter__in_bbs_body';

for my $x (1,2) {
    my $data = scalar reverse "ok $x\n";
    print POST_BODY $location, content => $data;
}
