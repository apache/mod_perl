package TestApache::post;

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use TestCommon::Utils ();

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;
    $r->content_type('text/plain');

    my $data = TestCommon::Utils::read_post($r) || "";

    $r->puts(join ':', length($data), $data);

    Apache2::OK;
}

1;
