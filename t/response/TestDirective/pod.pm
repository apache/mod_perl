package TestDirective::pod;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 3;

    ok t_cmp('yes', $r->dir_config->get('TestDirective__pod_over_worked'));
    ok t_cmp('yes', $r->dir_config->get('TestDirective__pod_cut_worked'));

    #XXX: How to test that __END__ works proprely without cloberring all the other tests?
    ok t_cmp('__END__', '__END__');

    Apache::OK;
}

1;
