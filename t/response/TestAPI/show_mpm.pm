package TestAPI::show_mpm;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::MPM ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 1;

    my $mpm = Apache::Test::config->{server}->{mpm};

    ok t_cmp(qr!$mpm!i,
             Apache::MPM::show_mpm,
             'Apache::MPM::show_mpm()');

    Apache::OK;
}

1;
