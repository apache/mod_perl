package TestAPR::os;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use APR::OS ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 2;

    if (Apache::MPM_IS_THREADED) {
        my $id = APR::OS::thread_current();
        ok t_cmp("$id", "$id", "current thread");
        ok t_cmp($$id, $$id, "current thread");
    }
    else {
        ok t_cmp($$, $$, "current process id");
        ok 1;
    }

    Apache::OK;
}

1;
