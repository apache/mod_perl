use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;
use Apache::Build ();

my $build = Apache::Build->build_config;
plan tests => 2, have 'LWP',
    {"MP_COMPAT_1X is disabled" => $build->{MP_COMPAT_1X}};

my $location = "/TestModules::cgiupload";

my $filename;
my $pod = 'pod/perlfunc.pod';

for (@INC) {
    if (-e "$_/$pod") {
        $filename = "$_/$pod";
        last;
    }
}

$filename ||= '../Makefile';

for (1,2) {
    my $str = UPLOAD_BODY $location, filename => $filename;
    my $body_len = length $str;
    my $file_len = -s $filename;
    t_debug "body_len=$body_len, file_len=$file_len";
    ok $body_len == $file_len;
}
