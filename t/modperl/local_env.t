use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest qw(GET);

plan tests => 1, skip_reason('local %ENV is still broken');

my $module = 'TestModperl::local_env';
my $url = Apache::TestRequest::module2url($module);
                      ;
my $failed;
foreach (1..25) {
    my $req = GET $url;
    unless ($req->is_success) {
        $failed = 1;
        last;
    }
}

ok !$failed;
