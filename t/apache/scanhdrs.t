use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 4;

my $module = 'TestApache::scanhdrs';
my $location = "/" . Apache::TestRequest::module2path($module);

my $res = GET $location;

t_debug $res->as_string;

ok t_cmp(qr/^ok 1$/m, $res->content);

ok t_cmp('text/test-output',
         $res->header('Content-Type'),
         "standard header");

ok t_cmp($module,
         $res->header('X-Perl-Module'),
         "custom header");

ok t_cmp(qr/beer/, $res->message);
