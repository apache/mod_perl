package TestAPRlib::base64;

# testing APR::Base64 API

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use APR::Base64;

sub num_of_tests {
    return 3;
}

sub test {

    my $str = '12345qwert!@#$%';
    my $encoded = APR::Base64::encode($str);

    t_debug("encoded string: $encoded");
    ok $encoded;

    ok t_cmp(APR::Base64::encode_len(length $str),
             length $encoded,
             "encoded length");

    ok t_cmp(APR::Base64::decode($encoded), $str, "decode");

}

1;
