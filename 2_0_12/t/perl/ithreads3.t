# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest 'GET_BODY';

plan tests => 6, need_apache_mpm('worker') && need_perl('ithreads');

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

t_debug("connecting to ".u(''));
ok t_cmp t('/perl-script?1'), 2, 'perl-script 1';
ok t_cmp t('/modperl?1'), 2, 'modperl 1';

ok t_cmp t('/perl-script?2'), 5, 'perl-script 2';
ok t_cmp t('/modperl?2'), 5, 'modperl 2';

ok t_cmp t('/perl-script?3'), 3, 'perl-script 3';
ok t_cmp t('/modperl?3'), 3, 'modperl 3';
