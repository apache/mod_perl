package TestAPI::query;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestTrace;

use Apache::MPM ();

use Apache::Const -compile => qw(OK :mpmq);

sub handler {

    my $r = shift;

    plan $r, tests => 5;

    # ok, this isn't particularly pretty, but I can't think
    # of a better way to do it
    # all of these attributes I pulled right from the C sources
    # so if, say, leader all of a sudden changes its properties,
    # these tests will fail

    my $mpm = lc Apache::MPM->show;

    if ($mpm eq 'prefork') {

        {
            my $query = Apache::MPM->query(Apache::MPMQ_IS_THREADED);

            ok t_cmp(Apache::MPMQ_NOT_SUPPORTED,
                     $query,
                     "MPMQ_IS_THREADED ($mpm)");

            # is_threaded() is just a constsub set to the result from
            # ap_mpm_query(AP_MPMQ_IS_THREADED)

            ok t_cmp($query,
                     Apache::MPM->is_threaded,
                     "Apache::MPM->is_threaded() equivalent to query(MPMQ_IS_THREADED)");

            t_debug('Apache::MPM->is_threaded returned ' . Apache::MPM->is_threaded);
            ok (! Apache::MPM->is_threaded);
        }

        {
            my $query = Apache::MPM->query(Apache::MPMQ_IS_FORKED);

            ok t_cmp(Apache::MPMQ_DYNAMIC,
                     $query,
                     "MPMQ_IS_FORKED ($mpm)");
        }

    }
    elsif ($mpm eq 'worker') {

        {
            my $query = Apache::MPM->query(Apache::MPMQ_IS_THREADED);

            ok t_cmp(Apache::MPMQ_STATIC,
                     $query,
                     "MPMQ_IS_THREADED ($mpm)");

            ok t_cmp($query,
                     Apache::MPM->is_threaded,
                     "Apache::MPM->is_threaded() equivalent to query(MPMQ_IS_THREADED)");

            t_debug('Apache::MPM->is_threaded returned ' . Apache::MPM->is_threaded);
            ok (Apache::MPM->is_threaded);
        }

        {
            my $query = Apache::MPM->query(Apache::MPMQ_IS_FORKED);

            ok t_cmp(Apache::MPMQ_DYNAMIC,
                     $query,
                     "MPMQ_IS_FORKED ($mpm)");
        }
    }
    elsif ($mpm eq 'leader') {

        {
            my $query = Apache::MPM->query(Apache::MPMQ_IS_THREADED);

            ok t_cmp(Apache::MPMQ_STATIC,
                     $query,
                     "MPMQ_IS_THREADED ($mpm)");

            ok t_cmp($query,
                     Apache::MPM->is_threaded,
                     "Apache::MPM->is_threaded() equivalent to query(MPMQ_IS_THREADED)");

            t_debug('Apache::MPM->is_threaded returned ' . Apache::MPM->is_threaded);
            ok (Apache::MPM->is_threaded);
        }

        {
            my $query = Apache::MPM->query(Apache::MPMQ_IS_FORKED);

            ok t_cmp(Apache::MPMQ_DYNAMIC,
                     $query,
                     "MPMQ_IS_FORKED ($mpm)");
        }
    }
    elsif ($mpm eq 'winnt') {

        {
            my $query = Apache::MPM->query(Apache::MPMQ_IS_THREADED);

            ok t_cmp(Apache::MPMQ_STATIC,
                     $query,
                     "MPMQ_IS_THREADED ($mpm)");

            ok t_cmp($query,
                     Apache::MPM->is_threaded,
                     "Apache::MPM->is_threaded() equivalent to query(MPMQ_IS_THREADED)");

            t_debug('Apache::MPM->is_threaded returned ' . Apache::MPM->is_threaded);
            ok (Apache::MPM->is_threaded);
        }

        {
            my $query = Apache::MPM->query(Apache::MPMQ_IS_FORKED);

            ok t_cmp(Apache::MPMQ_NOT_SUPPORTED,
                     $query,
                     "MPMQ_IS_FORKED ($mpm)");
        }
    }
    else {
        skip "skipping MPMQ_IS_THREADED test for $mpm MPM", 0;
        skip "skipping Apache::MPM->is_threaded equivalence test for $mpm MPM", 0;
        skip "skipping MPMQ_IS_FORKED test for $mpm MPM", 0;
        skip "skipping Apache::MPM->is_threaded test for $mpm MPM", 0;
    }

    # make sure that an undefined MPMQ constant yields undef
    {
        my $query = Apache::MPM->query(72);

        ok t_cmp(undef,
                 $query,
                 "unknown MPMQ value returns undef");
    }

    Apache::OK;
}

1;
