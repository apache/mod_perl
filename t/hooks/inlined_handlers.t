use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;
use TestCommon::SameInterp;

plan tests => 2, need 'HTML::HeadParser';

my $location = "/TestHooks__inlined_handlers";

t_debug "getting the same interp ID for $location";
my $same_interp = Apache::TestRequest::same_interp_tie($location);

my $skip = $same_interp ? 0 : 1;
my $expected = "ok";
for (1..2) {
    my $received = same_interp_req_body($same_interp, \&GET, $location);
    $skip++ unless defined $received;
    same_interp_skip_not_found(
        $skip,
        $received,
        $expected,
        "anonymous handlers in httpd.conf test"
    );
}

