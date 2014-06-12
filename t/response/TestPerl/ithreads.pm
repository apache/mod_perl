# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestPerl::ithreads;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestTrace;

use Apache2::Const -compile => 'OK';

# XXX: at this moment ithreads can be used only with 5.8.1. However
# once ithreads will be available on CPAN, we will need to change the
# check for perl 5.8.0 and this certain version of ithreads (here and
# in t/conf/post_config_startup.pl

sub handler {
    my $r = shift;

    plan $r, tests => 4, need
        need_threads,
        {"perl >= 5.8.1 is required (this is $])" => ($] >= 5.008001)};

    # threads must have been preloaded at the server startup for this
    # test (this is done at t/conf/post_config_startup.pl)
    require threads;
    threads->import();

    # sky: the more modules are loaded, the slower new ithreads start
    #      because more things need to be cloned
    debug '%INC size: ' . scalar(keys %INC) . "\n";

    {
        my $tid = threads->self->tid;
        debug "1st TID is $tid" if defined $tid;
        ok defined $tid;
    }

    {
        my $thr = threads->new(sub {
            my $tid = threads->self->tid;
            debug "2nd TID is $tid" if defined $tid;
            return 2;
        });
        ok t_cmp($thr->join, 2, "thread callback returned value");
    }

    {
        require threads::shared;
        my $counter_priv          = 1;
        my $counter_shar : shared = 1;

        my $thr = threads->new(sub {
            my $tid = threads->self->tid;
            debug "2nd TID is $tid" if defined $tid;
            $counter_priv += $counter_priv for 1..10;
            {
                lock $counter_shar;
                $counter_shar += $counter_shar for 1..10;
            }
        });

        $counter_priv += $counter_priv for 1..10;
        {
            lock $counter_shar;
            $counter_shar += $counter_shar for 1..10;
        }

        $thr->join;
        ok t_cmp($counter_shar, 2**20, "shared counter");
        ok t_cmp($counter_priv, 2**10, "private counter");
    }

    Apache2::Const::OK;
}

1;

__END__
# APACHE_TEST_CONFIG_ORDER 941

<VirtualHost TestPerl::ithreads>

    <IfDefine PERL_USEITHREADS>
        # a new interpreter pool
        PerlOptions +Parent
        PerlInterpStart         1
        PerlInterpMax           1
        PerlInterpMinSpare      1
        PerlInterpMaxSpare      1
    </IfDefine>

    # use test system's @INC
    PerlSwitches -I@serverroot@
    PerlRequire "conf/modperl_inc.pl"

    <Location /TestPerl__ithreads>
        SetHandler modperl
        PerlResponseHandler TestPerl::ithreads
    </Location>

</VirtualHost>
