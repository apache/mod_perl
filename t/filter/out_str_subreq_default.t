use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 1;

my $location = '/TestFilter__out_str_subreq_default';

my $content1    = "content\n";
my $content2    = "more content\n";
my $filter      = "filter\n";
my $subrequest  = "default-handler subrequest\n";

my $expected = join '', $content1, $subrequest, $content2, $filter;
my $received = GET_BODY $location;

ok t_cmp($expected, $received, 
    "testing filter-originated lookup_uri() call to core served URI");
