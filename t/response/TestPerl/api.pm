package TestPerl::api;

# some perl APIs that we need to test that they work alright under mod_perl

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestTrace;

use Apache::Build;

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 2,
        have { "getppid() is not implemented on Win32" 
                   => !Apache::Build::WIN32() };

    {
        # 5.8.1 w/ ithreads has a bug where it caches ppid in PL_ppid,
        # but updates the record only if perl's fork is called, which
        # is not the case with mod_perl. This results in getppid()
        # returning 1. A local workaround in the mod_perl source at
        # the child_init phase fixes the problem.
        my $ppid = getppid();
        t_debug "ppid $ppid";
        ok $ppid > 1;

        # verify that $pid != $ppid
        t_debug "pid $$";
        ok $ppid != $$;
    }

    Apache::OK;
}

1;
