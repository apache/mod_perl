use strict;
use warnings FATAL => 'all';

use Apache::Test;
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

my $expect = join(':', length($data), $data);
ok $str eq $expect;

print "EXPECT: $expect\n";
print "STR: $str\n";

