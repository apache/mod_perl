package TestApache::post;

use strict;
use warnings FATAL => 'all';

sub handler {
    my $r = shift;
    $r->content_type('text/plain');

    my $data = ModPerl::Test::read_post($r) || "";

    $r->puts(join ':', length($data), $data);

    0;
}

1;
