package TestAPR::base64;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use APR::Base64 ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 2;

    my $encoded = APR::Base64::encode("$r");

    ok $encoded;

    my $decoded = APR::Base64::decode($encoded);

    ok $decoded eq "$r";

    Apache::OK;
}

1;
