use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;
use TestCommon::SameInterp;

plan tests => 2, need 'HTML::HeadParser';

my $module   = 'TestAPR::pool_lifetime';
my $location = '/' . Apache::TestRequest::module2path($module);

t_debug "getting the same interp ID for $location";
my $same_interp = Apache::TestRequest::same_interp_tie($location);

my $skip = $same_interp ? 0 : 1;

for (1..2) {
    my $expected = "Pong";
    my $received = same_interp_req_body($same_interp, \&GET, $location);
    $skip++ unless defined $received;
    same_interp_skip_not_found(
        $skip,
        $expected,
        $received,
        "Pong"
    );
}
