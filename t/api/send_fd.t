use strict;
use warnings FATAL => 'all';

use Test;
use Apache::Test ();

plan tests => 3;

my $config = Apache::Test::config();

my $url = '/TestAPI::send_fd';

my $data = $config->http_raw_get($url);

ok $data;

my $module = 'response/TestAPI/send_fd.pm';

ok length($data) == -s $module;

$data = $config->http_raw_get("$url?noexist.txt");

ok $data =~ /Not Found/;
