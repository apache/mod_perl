package TestAPI::mpm_query;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestTrace;

use Apache::MPM ();

use Apache::Const -compile => qw(OK :mpmq);

sub handler {
    my $r = shift;

    plan $r, tests => 3;

    # ok, this isn't particularly pretty, but I can't think
    # of a better way to do it
    # all of these attributes I pulled right from the C sources

    my $mpm = lc Apache::MPM::show_mpm;

    if ($mpm eq 'prefork') {

        {
            my $query = Apache::MPM::mpm_query(Apache::MPMQ_IS_THREADED);

            ok t_cmp(Apache::MPMQ_NOT_SUPPORTED,
                     $query,
                     "MPMQ_IS_THREADED ($mpm)");
        }

        {
            my $query = Apache::MPM::mpm_query(Apache::MPMQ_IS_FORKED);

            ok t_cmp(Apache::MPMQ_DYNAMIC,
                     $query,
                     "MPMQ_IS_FORKED ($mpm)");
        }

        # the underlying call for Apache::MPM_IS_THREADED is ap_mpm_query
        # so might as well test is here...

        t_debug('Apache::MPM_IS_THREADED returned ' . Apache::MPM_IS_THREADED);
        ok (! Apache::MPM_IS_THREADED);

    }
    elsif ($mpm eq 'worker') {

        {
            my $query = Apache::MPM::mpm_query(Apache::MPMQ_IS_THREADED);

            ok t_cmp(Apache::MPMQ_STATIC,
                     $query,
                     "MPMQ_IS_THREADED ($mpm)");
        }

        {
            my $query = Apache::MPM::mpm_query(Apache::MPMQ_IS_FORKED);

            ok t_cmp(Apache::MPMQ_DYNAMIC,
                     $query,
                     "MPMQ_IS_FORKED ($mpm)");
        }

        t_debug('Apache::MPM_IS_THREADED returned ' . Apache::MPM_IS_THREADED);
        ok (Apache::MPM_IS_THREADED);

    }
    elsif ($mpm eq 'leader') {

        {
            my $query = Apache::MPM::mpm_query(Apache::MPMQ_IS_THREADED);

            ok t_cmp(Apache::MPMQ_STATIC,
                     $query,
                     "MPMQ_IS_THREADED ($mpm)");
        }

        {
            my $query = Apache::MPM::mpm_query(Apache::MPMQ_IS_FORKED);

            ok t_cmp(Apache::MPMQ_DYNAMIC,
                     $query,
                     "MPMQ_IS_FORKED ($mpm)");
        }

        t_debug('Apache::MPM_IS_THREADED returned ' . Apache::MPM_IS_THREADED);
        ok (Apache::MPM_IS_THREADED);

    }
    elsif ($mpm eq 'winnt') {

        {
            my $query = Apache::MPM::mpm_query(Apache::MPMQ_IS_THREADED);

            ok t_cmp(Apache::MPMQ_STATIC,
                     $query,
                     "MPMQ_IS_THREADED ($mpm)");
        }

        {
            my $query = Apache::MPM::mpm_query(Apache::MPMQ_IS_FORKED);

            ok t_cmp(Apache::MPMQ_NOT_SUPPORTED,
                     $query,
                     "MPMQ_IS_FORKED ($mpm)");
        }

        t_debug('Apache::MPM_IS_THREADED returned ' . Apache::MPM_IS_THREADED);
        ok (Apache::MPM_IS_THREADED);

    }
    else {
        skip "skipping MPMQ_IS_THREADED test for $mpm MPM", 0;
        skip "skipping MPMQ_IS_FORKED test for $mpm MPM", 0;
        skip "skipping Apache::MPM_IS_THREADED test for $mpm MPM", 0;
    }

    Apache::OK;
}

1;
