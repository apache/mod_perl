use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;
use Apache::Build ();

my $build = Apache::Build->build_config;

use constant HAVE_LWP => have_lwp();

my $tests = 4;
$tests += 1 if HAVE_LWP;

plan tests => $tests, have
    have_min_module_version(CGI => 3.01);

my $module = 'TestModules::cgi2';
my $location = '/' . Apache::TestRequest::module2path($module);

my($res, $str);

sok {
    my $url = "$location?PARAM=2";
    $res = GET $url;
    $str = $res->content;
    t_cmp("ok 2", $str, "GET $url");
};

sok {
    my $content = 'PARAM=%33';
    $str = POST_BODY $location, content => $content;
    t_cmp("ok 3", $str, "POST $location\n$content");
};

if (HAVE_LWP) {
    sok {
        $str = UPLOAD_BODY $location, content => 4;
        t_cmp("ok 4", $str, 'file upload');
    };
}

sok {
    my $header = 'Content-type';
    $res = GET $location;
    t_cmp(qr{^text/test-output},
          $res->header($header),
          "$header header");
};

sok {
    my $header = 'X-Perl-Module';
    $res = GET $location;
    t_cmp($module,
          $res->header($header),
          "$header header");
};
