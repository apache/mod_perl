package TestCompat::apache;

# Apache->"method" and Apache::"function" compat layer tests

# these tests are all run and validated on the server side.

use strict;
use warnings FATAL => 'all';

use Apache::TestUtil;
use Apache::Test;

use Apache::compat ();
use Apache::Constants qw(OK);

sub handler {
    my $r = shift;

    plan $r, tests => 5;

    $r->send_http_header('text/plain');

    ### Apache-> tests
    my $fh = Apache->gensym;
    ok t_cmp('GLOB', ref($fh), "Apache->gensym");

    ok t_cmp(1, Apache->module('mod_perl.c'),
             "Apache::module('mod_perl.c')");
    ok t_cmp(0, Apache->module('mod_ne_exists.c'),
             "Apache::module('mod_ne_exists.c')");


    ok t_cmp(Apache::exists_config_define('MODPERL2'),
             Apache->define('MODPERL2'),
             'Apache->define');

    Apache::log_error("Apache::log_error test ok");
    ok 1;

    OK;
}

1;

