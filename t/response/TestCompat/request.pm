package TestCompat::request;

# $r->"method" compat layer tests

# these tests are all run and validated on the server side.

use strict;
use warnings FATAL => 'all';

use Apache::TestUtil;
use Apache::Test;

use Apache::compat ();
use Apache::Constants qw(OK REMOTE_HOST);

sub handler {
    my $r = shift;

    plan $r, tests => 16;

    $r->send_http_header('text/plain');

    # header_in() and header_out() and err_header_out()
    for my $prefix ('err_', '') {
        my @ways = 'out';
        push @ways, 'in' unless $prefix;
        for my $way (@ways) {
            my $sub_test = "${prefix}header_$way";
            my $sub_good = "${prefix}headers_$way";
            my $key = 'header-test';

            # scalar context
            {
                my $key;
                if ($way eq 'in') {
                    $key = "user-agent"; # should exist with lwp
                } else {
                    # outgoing headers aren't set yet, so we set one
                    $key = "X-barabara";
                    $r->$sub_good->set($key, $key x 2);
                }

                ok t_cmp($r->$sub_good->get($key),
                         $r->$sub_test($key),
                         "\$r->$sub_test in scalar context");
            }

            # list context
            {
                my @exp = qw(foo bar);
                $r->$sub_good->add($key => $_) for @exp;
                ok t_cmp(\@exp,
                         [ $r->$sub_test($key) ],
                         "\$r->$sub_test in list context");
            }

            # set
            {
                my $exp = $key x 2;
                $r->$sub_test($key => $exp);
                my $got = $r->$sub_test($key);
                ok t_cmp($exp, $got, "\$r->$sub_test set()");
            }

            # unset
            {
                my $exp = undef;
                $r->$sub_test($key => $exp);
                my $got = $r->$sub_test($key);
                ok t_cmp($exp, $got, "\$r->$sub_test unset()");
            }
        }
    }

    # get_remote_host()
    ok $r->get_remote_host() || 1;
    ok $r->get_remote_host(Apache::REMOTE_HOST) || 1;

    # post_connection()
    $r->post_connection(sub { OK });
    ok 1;

    # register_cleanup
    ok 1;
    $r->register_cleanup(sub { OK });

    OK;
}

1;

