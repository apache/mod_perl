package TestHooks::fixup;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

sub handler {
    my $r = shift;

    $r->notes->set(ok => 1);

    Apache::OK;
}

sub response {
    my $r = shift;

    plan $r, tests => 1;

    ok $r->notes->get('ok');

    Apache::OK;
}

1;
__DATA__
PerlResponseHandler TestHooks::fixup::response
SetHandler modperl
