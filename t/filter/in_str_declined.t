use strict;
use warnings FATAL => 'all';

use Apache::TestRequest;

my $location = '/TestFilter::in_str_declined';

my $chunk = "1234567890";
my $data = $chunk x 2000;

my $res = POST $location, content => $data;

if ($res->is_success) {
    print $res->content;
}
else {
    die "server side has failed (response code: ", $res->code, "),\n",
        "see t/logs/error_log for more details\n";
}
