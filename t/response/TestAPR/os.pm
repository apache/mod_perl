package TestAPR::os;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use APR::OS ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 1;

    my $id = APR::OS::thread_current() || $$;

    ok t_cmp($id, $id, "current thread id or process id");

    Apache::OK;
}

1;
