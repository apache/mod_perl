package TestModperl::ithreads;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestTrace;

use Apache::Const -compile => 'OK';

# XXX: at this moment ithreads can be used only with 5.8.1. However
# once ithreads will be available on CPAN, we will need to change the
# check for perl 5.8.0 and this certain version of ithreads (here and
# in t/conf/modperl_extra.pl

sub handler {
    my $r = shift;

    plan $r, tests => 4, have
        have_threads,
        {"perl >= 5.8.1 is required (this is $])" => ($] >= 5.008001)};

    # threads must have been preloaded at the server startup for this
    # test (this is done at t/conf/modperl_extra.pl)
    require threads;
    threads->import();

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
        ok t_cmp(2, $thr->join, "thread callback returned value");
    }

    {
        require threads::shared;
        my $counter_priv          = 1;
        my $counter_shar : shared = 1;
        my $thr = threads->new(sub : locked { 
                                   my $tid = threads->self->tid; 
                                   debug "2nd TID is $tid" if defined $tid;
                                   $counter_priv += $counter_priv for 1..10;
                                   $counter_shar += $counter_shar for 1..10;
                                   return 2;
                               });
        $counter_priv += $counter_priv for 1..10;
        $counter_shar += $counter_shar for 1..10;
        my $ret = $thr->join;
        ok t_cmp(2**20, $counter_shar, "shared counter");
        ok t_cmp(2**10, $counter_priv, "private counter");
    }

    Apache::OK;
}

1;
__END__
SetHandler modperl
