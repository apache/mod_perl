package TestModperl::request_rec_tie_api;

use strict;
use warnings FATAL => 'all';

use Apache::RequestIO ();

use Apache::Test;
use Apache::TestUtil;

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 1;

    ok t_cmp(fileno(STDOUT), $r->FILENO(), "FILENO");

    return Apache::OK;
}

1;
