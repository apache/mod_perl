# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

use Config;

my $uri = "/TestModperl__request_rec_perlio_api";

plan tests => 2, need { "perl $]: TIEd IO is used instead of PerlIO"
                            => ($] >= 5.008 && $Config{useperlio}) };


{
    # t/response/TestModperl/request_rec_perlio_api.pm reads the first few
    # bytes from the .pm file itself. If these are changed remember to change
    # the expected bytes here as well.
    my $content  = join "", 'a'..'j', 'k'..'t';
    my $location = "$uri?STDIN";
    my $expected = join("", 'a'..'j',
                        "# please insert nothing before this line", 'k'..'t');
    my $received = POST_BODY_ASSERT $location, content => $content;
    ok t_cmp($received, $expected, "STDIN tests");
}

{
    my $location = "$uri?STDOUT";
    my $expected = "life is hard and then you die! next you reincarnate...";
    my $received = GET_BODY_ASSERT $location;
    ok t_cmp($received, $expected, "STDOUT tests");
}
