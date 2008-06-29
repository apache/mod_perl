# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest 'GET_BODY';

plan tests => 20, need_apache_mpm('worker') && need_perl('ithreads') && need_lwp;

my $module = 'TestPerl::ithreads3';

sub u {Apache::TestRequest::module2url($module, {path=>$_[0]})}
sub t {
    my $rc;
    eval {
        local $SIG{ALRM}=sub {die "Timeout\n"};
        alarm 2;
        eval {
            $rc=GET_BODY u(shift);
        };
        alarm 0;
    };
    alarm 0;
    return $rc;
}

Apache::TestRequest::user_agent(reset => 1, keep_alive=>1);

t_debug("connecting to ".u(''));

my ($t, $descr);

$t=1;
$descr='each phase new interp';
ok t_cmp t('/perl-script/?'.$t), '1,1,1,1,1', 'perl-script: '.$descr;
ok t_cmp t('/modperl/?'.$t), '1,1,1,1,1', 'modperl: '.$descr;
ok t_cmp t('/refcnt/?'.$t), '0,0,0,0,1', 'refcnt: '.$descr;

$t=2;
$descr='interp locked by $r->pnotes';
ok t_cmp t('/perl-script/?'.$t), '1,2,3,4,5', 'perl-script: '.$descr;
ok t_cmp t('/cleanupnote/?0'), 'PerlResponseHandler', 'cleanupnote: '.$descr;
ok t_cmp t('/modperl/?'.$t), '1,2,3,4,5', 'modperl: '.$descr;
ok t_cmp t('/refcnt/?'.$t), '0,1,1,1,2', 'refcnt: '.$descr;

$t=3;
$descr='interp locked from trans to fixup';
ok t_cmp t('/perl-script/?'.$t), '1,2,3,4,1', 'perl-script: '.$descr;
ok t_cmp t('/cleanupnote/?0'), 'PerlFixupHandler', 'cleanupnote: '.$descr;
ok t_cmp t('/modperl/?'.$t), '1,2,3,4,1', 'modperl: '.$descr;
ok t_cmp t('/refcnt/?'.$t), '0,1,1,1,1', 'refcnt: '.$descr;

$t=4;
$descr='interp locked by $r->connection->pnotes';
ok t_cmp t('/perl-script/?'.$t), '1,2,3,4,5', 'perl-script: '.$descr;
ok t_cmp t('/modperl/?'.$t), '1,2,3,4,5', 'modperl: '.$descr;
ok t_cmp t('/refcnt/?'.$t), '1,1,1,1,2', 'refcnt: '.$descr;

Apache::TestRequest::user_agent(reset => 1, keep_alive=>1);

$t=4;
t('/refcnt/?'.$t);
$t=5;
$descr='interp locked by $r->connection->pnotes 2nd call';
ok t_cmp t('/perl-script/?'.$t), '1,2,3,4,5,6,7,8,9,10,11', 'perl-script: '.$descr;
ok t_cmp t('/modperl/?'.$t), '1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16', 'modperl: '.$descr;
ok t_cmp t('/refcnt/?'.$t), '0,1,1,1,2,2,1,1,1,1,2,1,1,1,1,2,1,1,1,1,2', 'refcnt: '.$descr;

Apache::TestRequest::user_agent(reset => 1, keep_alive=>1);

$t=4;
t('/refcnt/?'.$t);
$t=6;
$descr='interp unlocked after  2nd call';
ok t_cmp t('/modperl/?'.$t), '1,2,3,4,5,6,7,8,1,1,1', 'modperl: '.$descr;
ok t_cmp t('/refcnt/?'.$t), '0,1,1,1,2,2,1,1,0,0,1,1,0,1,0,0,1', 'refcnt: '.$descr;
ok t_cmp t('/cleanupnote/?0'), 'PerlMapToStorageHandler', 'cleanupnote: '.$descr;
