use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 6, \&have_lwp;

my $module = 'TestModules::cgi';
my $location = "/$module";

ok 1;

my $res = GET "$location?PARAM=2";
my $str = $res->content;
ok $str eq "ok 2\n" or print "str=$str";

$str = POST_BODY $location, content => 'PARAM=%33';
ok $str eq "ok 3\n" or print "str=$str";

$str = UPLOAD_BODY $location, content => 4;
ok $str eq "ok 4\n" or print "str=$str";

ok $res->header('Content-type') =~ m:^text/test-output:;

ok $res->header('X-Perl-Module') eq $module;
