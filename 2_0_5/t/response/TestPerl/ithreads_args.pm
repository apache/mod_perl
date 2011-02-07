package TestPerl::ithreads_args;

# reproducing a bug in perl ithreads: [perl #34342]
# https://rt.perl.org/rt3/Ticket/Display.html?id=34342
#
# here an unshifted $r (i.e. as it leaves @_ populated causes a scalar
# leak in the thread).

use Devel::Peek;
use Apache::Test;

sub handler {   # XXX: unshifted $_[0] leaks scalar
    #Dump $_[0];
    #my $r = shift; # shift removes the leak
    my $r = $_[0];
    #Dump $r; # here PADBUSY,PADMY prevent the ithread from cloning it

    plan $r, tests => 1, need
        need_threads,
            {"perl >= 5.8.1 is required (this is $])" => ($] >= 5.008001)};

    require threads;

    warn "\n*** The following leak is expected (perl bug #34342) ***\n";
    threads->new(sub {})->join;

    ok 1;

    return 0;
}

1;
