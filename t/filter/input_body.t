use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

#XXX: skip input_body filter test until filter changes dust settles
plan tests => 2, \&have_lwp;

my $location = '/TestFilter::input_body';

for my $x (1,2) {
    my $data = scalar reverse "ok $x\n";
    print POST_BODY $location, content => $data;
}
