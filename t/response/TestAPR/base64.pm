package TestAPR::base64;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use APR::Base64 ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 3;

    my $str = "$r";
    my $encoded = APR::Base64::encode($str);

    t_debug("encoded string: $encoded");
    ok $encoded;

    ok t_cmp(APR::Base64::encode_len(length $str),
             length $encoded,
             "encoded length");

    ok t_cmp(APR::Base64::decode($encoded), $str, "decode");

    Apache::OK;
}

1;
