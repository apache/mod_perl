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

    ok ! APR::Util::password_validate("one", "two");

    my $clear = "pass1";
    my $hash  = "1fWDc9QWYCWrQ";
    ok APR::Util::password_validate($clear, $hash);

    Apache::OK;
}

1;
