use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 2;

my $module = 'TestApache::cookie2';
my $location = Apache::TestRequest::module2path($module);
my $cookie = 'foo=bar';

t_debug("Testing cookie in PerlResponseHandler");

for (qw/header env/) {
    t_debug("-- testing cookie from $_");
    my $res = GET "$location?$_", Cookie => $cookie;

    ok t_cmp('bar', $res->content,
             "content is 'bar'");
}

