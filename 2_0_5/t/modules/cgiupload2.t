use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;
use Apache2::Build ();

use File::Spec::Functions qw(catfile);

my $build = Apache2::Build->build_config;
plan tests => 2, need need_lwp(),
    need_min_module_version(CGI => 3.08);

my $location = "/TestModules__cgiupload2";

my $filename;
my $pod = 'pod/perlfunc.pod';

for (@INC) {
    if (-e "$_/$pod") {
        $filename = "$_/$pod";
        last;
    }
}

$filename ||= catfile Apache::Test::vars('serverroot'), "..", 'Makefile';

for (1,2) {
    t_client_log_warn_is_expected(4)
        if $] < 5.008 && require CGI && $CGI::VERSION < 3.06;
    my $str = UPLOAD_BODY $location, filename => $filename;
    my $body_len = length $str;
    my $file_len = -s $filename;
    t_debug "body_len=$body_len, file_len=$file_len";
    ok $body_len == $file_len;
}
