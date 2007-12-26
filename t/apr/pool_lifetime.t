use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;
Apache::TestRequest::user_agent(keep_alive => 1);

plan tests => 2, need 'HTML::HeadParser';

my $module   = 'TestAPR::pool_lifetime';
my $location = '/' . Apache::TestRequest::module2path($module);

t_debug "getting the same interp ID for $location";

for (1..2) {
    my $expected = "Pong";
    my $received = GET "$location";

    ok t_cmp(
        $received->content,
        $expected,
        "Pong",
    );
}
