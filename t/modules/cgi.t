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
print $str;

$str = POST_BODY $location, content => 'PARAM=%33';
print $str;

$str = UPLOAD_BODY $location, content => 4;
print $str;

$Test::ntest += 3;

ok $res->header('Content-type') =~ m:^text/test-output:;

ok $res->header('X-Perl-Module') eq $module;
