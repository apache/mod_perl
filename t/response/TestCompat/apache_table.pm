package TestCompat::apache_table;

# Apache2::Table compat layer tests

# these tests are all run and validated on the server side.

use strict;
use warnings FATAL => 'all';

use Apache::TestUtil;
use Apache::Test;

use Apache2::compat ();
use Apache2::Constants qw(OK);

sub handler {
    my $r = shift;

    plan $r, tests => 2;

    $r->send_http_header('text/plain');

    my $t = Apache2::Table->new($r);
    my $t_class = ref $t;

    ok t_cmp($t_class, 'APR::Table', "Apache2::Table->new");

    ok t_cmp($r->is_main, !$r->main,
             '$r->is_main');

    OK;
}

1;

