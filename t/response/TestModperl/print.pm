package TestModperl::print;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

sub handler {
    my $r = shift;

    plan $r, tests => 3;

    ok 1;

    ok 2;

    printf "ok %d", 3;

    Apache::OK;
}

1;
