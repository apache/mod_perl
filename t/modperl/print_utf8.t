use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;

# utf encode/decode was added only in 5.8.0
# currently binmode is only available with perlio
plan tests => 1, have have_min_perl_version(5.008), have_perl('perlio');

#use bytes;
#use utf8;

my $location = "/TestModperl__print_utf8";

my $received = GET_BODY_ASSERT $location;

# the external stream already include wide-chars, but perl doesn't
# know about it
utf8::decode($received);

binmode(STDOUT, ':utf8');


my $expected = "Hello Ayhan \x{263A} perlio rules!";

print "$expected\n";
print "$received\n";

#ok $expected eq $received;

ok t_cmp($expected, $received, 'UTF8 encoding');

