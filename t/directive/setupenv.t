use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

plan tests => 3;

my $location = '/TestDirective::setupenv';

my $env = GET_BODY $location;

ok $env;

my %env;

for my $line (split /\n/, $env) {
    next unless $line =~ /=/;
    my($key, $val) = split /=/, $line, 2;
    $env{$key} = $val || '';
}

ok t_cmp $location, $env{REQUEST_URI}, "testing REQUEST_URI";

ok not exists $env{HOME};
