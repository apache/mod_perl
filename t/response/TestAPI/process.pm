package TestAPI::process;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::RequestRec ();
use Apache::ServerRec ();
use Apache::Process ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 4;

    my $s = $r->server;
    my $proc = $s->process;
    ok t_cmp(1, $proc->isa('Apache::Process'), "isa('Apache::Process')");

    my $global_pool = $proc->pool;
    ok t_cmp(1, $global_pool->isa('APR::Pool'), "pglob isa('APR::Pool')");

    my $pconf = $proc->pconf;
    ok t_cmp(1, $pconf->isa('APR::Pool'), "pconf isa('APR::Pool')");

    my $proc_name = $proc->short_name;
    t_debug($proc_name);
    ok $proc_name;

    Apache::OK;
}

1;

__END__
