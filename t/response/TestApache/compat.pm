package TestApache::compat;

use strict;
use warnings FATAL => 'all';

use Apache::compat ();

use Apache::Constants qw(OK M_POST);

sub handler {
    my $r = shift;

    $r->send_http_header('text/plain');

    my %data;
    if ($r->method_number == M_POST) {
        %data = $r->content;
    }
    else {
        %data = $r->Apache::args;
    }

    $r->print("ok $data{ok}");

    OK;
}

1;
