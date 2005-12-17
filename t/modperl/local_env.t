use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest qw(GET);

plan tests => 1;

my $url = '/TestModperl__local_env';

my $failed;
foreach (1..25) {
    my $req = GET $url;
    unless ($req->is_success) {
        $failed = 1;
        last;
    }
}

ok !$failed;
