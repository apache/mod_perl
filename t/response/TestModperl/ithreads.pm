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

    plan $r, tests => 2, have
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
        ok $thr->join == 2;
    }

    Apache::OK;
}

1;
__END__
SetHandler modperl
