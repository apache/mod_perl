package TestApache::post;

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;
    $r->content_type('text/plain');

    my $data = ModPerl::Test::read_post($r) || "";

    $r->puts(join ':', length($data), $data);

    Apache::OK;
}

1;
