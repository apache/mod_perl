use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(GET_BODY);

plan tests => 2;

my $module = 'TestApache::cookie';
my $location = Apache::TestRequest::module2path($module);
my $val = "bar";
my $cookie = "key=$val";

my %expected = 
(
    header => $val,
    env    => '',
);

for (qw/header env/) {
    my $received = GET_BODY "$location?$_", Cookie => $cookie;
    ok t_cmp($expected{$_}, $received);
}

