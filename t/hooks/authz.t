# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 4, need need_lwp, 'HTML::HeadParser';

my $location = "/TestHooks__authz";

ok ! GET_OK $location;

my $rc = GET_RC $location;

ok $rc == 401;

ok GET_OK $location, username => 'dougm', password => 'foo';

ok ! GET_OK $location, username => 'jobbob', password => 'whatever';


