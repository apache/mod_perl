use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 4;

my $module = 'TestApache::scanhdrs';
my $location = "/$module";

my $res = GET $location;

ok $res->content =~ /^ok 1$/m;

ok $res->header('Content-Type') eq 'text/test-output';

ok $res->header('X-Perl-Module') eq $module;

ok $res->message =~ /beer/;
