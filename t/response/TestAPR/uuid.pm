package TestAPR::uuid;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use APR::UUID ();

use Apache::Const -compile => 'OK';

my $dummy_uuid = 'd48889bb-d11d-b211-8567-ec81968c93c6';

sub handler {
    my $r = shift;

    plan $r, tests => 3;

#XXX: apr_generate_random_bytes may block forever on /dev/random
#    my $uuid = APR::UUID->new->format;
    my $uuid = $dummy_uuid;

    ok $uuid;

    my $uuid_parsed = APR::UUID->parse($uuid);

    ok $uuid_parsed;

    ok $uuid eq $uuid_parsed->format;

    Apache::OK;
}

1;
