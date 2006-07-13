use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my $module = 'TestModperl::local_env';
my $url    = Apache::TestRequest::module2url($module);

t_debug "connecting to $url";
print GET_BODY_ASSERT $url;

__END__
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest qw(GET);

plan tests => 1;

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
