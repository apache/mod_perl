use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 2;

my $location = "/TestApache::post";
my $str;

my @data = (arizona => 'wildcats');
my %data = @data;

$str = POST_BODY $location, content => "@data";

ok $str;

my $data = join '&', map { "$_=$data{$_}" } keys %data;

$str = POST_BODY $location, content => $data;
ok t_cmp(join(':', length($data), $data),
    $str,
    "POST");
