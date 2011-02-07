use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;
use TestCommon::SameInterp;

plan tests => 2, need 'HTML::HeadParser';

my $location = "/TestHooks__inlined_handlers";

my $expected = "ok";
for (1..2) {
    my $received = GET $location;

    ok t_cmp(
        $received->content,
        $expected,
        "anonymous handlers in httpd.conf test",
    );
}

