use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 4;

my $module = 'TestApache::scanhdrs';
my $location = "/$module";

my $res = GET $location;

t_debug $res->as_string;

ok t_cmp(qr/^ok 1$/m, $res->content);

ok t_cmp('text/test-output', scalar $res->header('Content-Type'));

ok t_cmp($module, scalar $res->header('X-Perl-Module'));

ok t_cmp(qr/beer/, $res->message);
