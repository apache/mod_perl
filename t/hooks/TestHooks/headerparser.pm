package TestHooks::headerparser;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

sub handler {
    my $r = shift;

    $r->notes->set(url => $ENV{REQUEST_URI});

    Apache::OK;
}

sub response {
    my $r = shift;

    plan $r, tests => 1;

    ok $r->notes->get('url') eq $r->uri;

    Apache::OK;
}

1;
__DATA__
PerlOptions +SetupEnv
PerlResponseHandler TestHooks::headerparser::response
SetHandler modperl
