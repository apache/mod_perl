package TestAPR::util;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use APR::Util ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 2;

#this function seems unstable on certain platforms
#    my $blen = 10;
#    my $bytes = APR::generate_random_bytes($blen);
#    ok length($bytes) == $blen;

    my $status = APR::password_validate("one", "two");

    ok $status != 0;

    my $str= APR::strerror($status);

    t_debug "strerror=$str\n";

    ok $str eq 'passwords do not match';

    Apache::OK;
}

1;
