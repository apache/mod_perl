use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;
use Apache2::Build ();

my $build = Apache2::Build->build_config;

use constant HAVE_LWP => have_lwp();

my $tests = 4;
$tests += 1 if HAVE_LWP;

plan tests => $tests, need
    need_min_module_version(CGI => 3.08);

my $module = 'TestModules::cgi2';
my $location = '/' . Apache::TestRequest::module2path($module);

my($res, $str);

sok {
    my $url = "$location?PARAM=2";
    $res = GET $url;
    $str = $res->content;
    t_cmp($str, "ok 2", "GET $url");
};

sok {
    my $content = 'PARAM=%33';
    $str = POST_BODY $location, content => $content;
    t_cmp($str, "ok 3", "POST $location\n$content");
};

if (HAVE_LWP) {
    sok {
        t_client_log_warn_is_expected(4)
            if $] < 5.008 && require CGI && $CGI::VERSION < 3.06;
        $str = UPLOAD_BODY $location, content => 4;
        t_cmp($str, "ok 4", 'file upload');
    };
}

sok {
    my $header = 'Content-type';
    $res = GET $location;
    t_cmp($res->header($header),
          qr{^text/test-output},
          "$header header");
};

sok {
    my $header = 'X-Perl-Module';
    $res = GET $location;
    t_cmp($res->header($header),
          $module,
          "$header header");
};
