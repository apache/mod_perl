package TestCompat::apache_uri;

# Apache::Util compat layer tests

# these tests are all run and validated on the server side.

use strict;
use warnings FATAL => 'all';

use Apache::TestUtil;
use Apache::Test;

use Apache::compat ();
use Apache::Constants qw(OK);

sub handler {
    my $r = shift;

    plan $r, tests => 1;

    # XXX: need to test ->parse
    #    {
    #        my @methods = qw(scheme hostinfo user password hostname path rpath
    #                         query fragment port unparse);
    #        my $test_uri = "http://foo:bar@perl.apache.org:80/docs/index.html";
    # 
    #        for my $uri ($r->parsed_uri, Apache::URI->parse($r, $test_uri)) {
    #            t_debug("URI=" . $uri->unparse);
    #            no strict 'refs';
    #            for my $meth (@methods) {
    #                my $val = $uri->$meth();
    #                t_debug("$meth: $val");
    #                ok $val || 1;
    #            }
    #        }
    #    }

    {
        Apache::compat::override_mp2_api('APR::URI::unparse');
        # test the segfault in apr < 0.9.2 (fixed on mod_perl side)
        # passing only the /path
        my $parsed = $r->parsed_uri;
        # set hostname, but not the scheme
        $parsed->hostname($r->get_server_name);
        $parsed->port($r->get_server_port);
        #$parsed->scheme('http'); # compat defaults to 'http' like apache-1.3 did
        ok t_cmp($r->construct_url, $parsed->unparse);
        Apache::compat::restore_mp2_api('APR::URI::unparse');
    }

    OK;
}

1;
