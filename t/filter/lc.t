use strict;
use warnings FATAL => 'all';

use Test;
use Apache::TestRequest;

plan tests => 1;

my $location = "/pod/modperl_2.0.pod";

my $str = GET_BODY $location;

ok $str !~ /[A-Z]/;
