
use Apache::Test;

use blib;
use Apache2;

use APR ();
use APR::UUID ();

my $dummy_uuid = 'd48889bb-d11d-b211-8567-ec81968c93c6';

plan tests => 3;

#XXX: apr_generate_random_bytes may block forever on /dev/random
#    my $uuid = APR::UUID->new->format;
my $uuid = $dummy_uuid;

ok $uuid;

my $uuid_parsed = APR::UUID->parse($uuid);

ok $uuid_parsed;

ok $uuid eq $uuid_parsed->format;

