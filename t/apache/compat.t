use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 2, \&have_lwp;

my $location = "/TestApache::compat";
my $str;

my @data = (ok => '2');
my %data = @data;

$str = POST_BODY $location, \@data;

ok $str eq "@data";

my $q = join '=', @data;
$str = GET_BODY "$location?$q";

ok $str eq "@data";

