use strict;
use warnings FATAL => 'all';

# test internal redirects originating from 'SetHandler modperl' and
# 'SetHandler perl-script' main handlers, and sub-requests handled by
# the handlers of the same and the opposite kind

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

use Config;

my $uri = "/TestModperl__request_rec_perlio_api";

plan tests => 2, have { "perl $]: TIEd IO is used instead of PerlIO"
                            => ($] >= 5.008 && $Config{useperlio}) };


{
    my $content  = join "", 'a'..'j', 'k'..'t';
    my $location = "$uri?STDIN";
    my $expected = join "", 'a'..'j', "<samba>", 'k'..'t';
    my $received = POST_BODY_ASSERT $location, content => $content;
    ok t_cmp($expected, $received, "STDIN tests");
}

{
    my $location = "$uri?STDOUT";
    my $expected = "life is hard and then you die! next you reincarnate...";
    my $received = GET_BODY_ASSERT $location;
    ok t_cmp($expected, $received, "STDOUT tests");
}
