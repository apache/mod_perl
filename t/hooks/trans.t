use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

use Apache2 ();
use Apache::Const ':common';

plan tests => 3;

ok GET_RC('/nope') == NOT_FOUND;

my $module = '/TestHooks/trans.pm';

my $body = GET_BODY $module;

ok $body =~ /package TestHooks::trans/;

ok GET_OK '/phooey';
