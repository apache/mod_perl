use strict;
use warnings FATAL => 'all';

use Test;
use Apache::Test ();
use Apache::TestRequest;

plan tests => 3;

my $config = Apache::Test::config();

my $url = '/TestAPI::send_fd';

my $data = GET_BODY($url);

ok $data;

my $module = 'response/TestAPI/send_fd.pm';

ok length($data) == -s $module;

$data = GET_BODY("$url?noexist.txt");

ok $data =~ /Not Found/;
