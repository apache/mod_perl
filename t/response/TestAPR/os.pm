package TestAPR::os;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::MPM ();
use APR::OS ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 1;

    if (Apache::MPM->is_threaded) {
        my $tid = APR::OS::current_thread_id();
        ok t_cmp($tid, $tid, "current thread id: $tid / pid: $$");
    }
    else {
        ok t_cmp($$, $$, "current process id");
    }

    Apache::OK;
}

1;
