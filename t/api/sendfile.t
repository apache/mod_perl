use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

use File::Spec::Functions qw(catfile);

my $url = '/TestAPI__sendfile';

my $file = catfile Apache::Test::vars('serverroot'),
    'response/TestAPI/sendfile.pm';

plan tests => 5;

{
    my $header = "This is a header\n";
    my $footer = "This is a footer\n";

    open my $fh, $file or die "can't open $file: $!";
    local $/;
    my $expected = join '', $header, <$fh>, $footer;
    close $fh;

    my $received = GET_BODY($url);

    t_debug($received);
    ok $received && $received eq $expected;
}

{
    my $res = GET "$url?noexist.txt";
    # 200 even though it wasn't found (since an output was sent before
    # sendfile was done)
    ok t_cmp($res->code, 200, "output already sent");
    t_debug($res->content);
    ok $res->content =~ /an internal error/;
}

{
    # this time no printed output but the attempt to read a
    # non-existing file
    my $res = GET "$url?noexist-n-noheader.txt";
    ok t_cmp($res->code, 404, "");
    t_debug($res->content);
    ok $res->content =~ /$url was not found/;
}
