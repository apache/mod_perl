package TestAPR::util;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use APR::Util ();

sub handler {
    my $r = shift;

    plan $r, tests => 3;

    my $blen = 10;
    my $bytes = APR::Util::generate_random_bytes(10);
    ok length($bytes) == $blen;

    my $status = APR::Util::password_validate("one", "two");

    ok $status != 0;

    my $str= APR::Util::strerror($status);

    t_debug "strerror=$str\n";

    ok $str eq 'passwords do not match';

    0;
}

1;
