use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 2;

my $location = "/TestApache::cgihandler";
my $str;

my $data = "1..3\nok 1\nok 2\nok 3\n";

$str = POST_BODY $location, content => $data;

ok $str eq $data;

$str = GET_BODY $location;

ok $str eq $data;
