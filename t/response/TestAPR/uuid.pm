package TestAPR::uuid;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use APR::UUID ();

sub handler {
    my $r = shift;

    plan $r, tests => 3;

    my $uuid = APR::UUID->new->format;

    ok $uuid;

    my $uuid_parsed = APR::UUID->parse($uuid);

    ok $uuid_parsed;

    ok $uuid eq $uuid_parsed->format;

    0;
}

1;
