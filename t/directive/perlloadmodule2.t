use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my $url = "/TestDirective::perlloadmodule2";

plan tests => 3;

{
    my $location = "$url?srv";
    my $expected = "srv: one two";
    my $received = GET_BODY $location;
    ok t_cmp($expected, $received, "access server settings");
}

{
    my $location = "$url?";
    my $expected = "dir: one two three four";
    my $received = GET_BODY $location;
    ok t_cmp($expected, $received, "server/dir merge");
}

{
    my $location = "$url/subdir";
    my $expected = "dir: one two three four five six";
    my $received = GET_BODY $location;
    ok t_cmp($expected, $received, "server/dir/subdir merge");
}
