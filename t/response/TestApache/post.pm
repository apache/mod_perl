package TestApache::post;

use strict;
use warnings FATAL => 'all';

use APR::Table ();

sub read_post {
    my $r = shift;

    $r->setup_client_block;

    return undef unless $r->should_client_block;

    my $len = $r->headers_in->get('content-length');

    my $buf;
    $r->get_client_block($buf, $len);

    return $buf;
}

sub handler {
    my $r = shift;
    $r->content_type('text/plain');

    my $data = read_post($r) || "";

    $r->puts(join ':', length($data), $data);

    0;
}

1;
