# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
# perl/ithreads is a similar test but is running from the global perl
# interpreter pool. whereas this test is running against a
# virtual host with its own perl interpreter pool (+Parent)

use strict;
use warnings FATAL => 'all';

use Config;

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest 'GET_BODY_ASSERT';

# perl < 5.6.0 fails to compile code with 'shared' attributes, so we must skip
# it here.
unless ($] >= 5.008001 && $Config{useithreads}) {
    plan tests => 1, need
        {"perl 5.8.1 or higher w/ithreads enabled is required" => 0};
}

my $module = 'TestPerl::ithreads';
my $url    = Apache::TestRequest::module2url($module);

t_debug("connecting to $url");
print GET_BODY_ASSERT $url;
