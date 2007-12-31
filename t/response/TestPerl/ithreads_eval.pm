package TestPerl::ithreads_eval;

# reproducing a bug in perl ithreads: [perl #34341]
# https://rt.perl.org/rt3/Ticket/Display.html?id=34341
#
# $thr->join triggers the following leak:
# - due to to local $0, (its second MAGIC's MG_OBJ,
#   you can see it in the output of Dump $0). This leak was first
#   spotted in the RegistryCooker.pm which localizes $0

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Devel::Peek;

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 1, need
        need_threads,
            {"perl >= 5.8.1 is required (this is $])" => ($] >= 5.008001)};

    require threads;

    eval <<'EOI';
sub mytest {
    local $0 = 'mememe'; # <== XXX: leaks scalar
    my $thr;
    $thr = threads->new(\&mythread);
    $thr->join;          # <== XXX: triggers scalar leak
}
sub mythread {
    #Dump $0;
}
EOI

    warn "\n*** The following leak is expected (perl bug #34341) ***\n";
    mytest();

    ok 1;

    return Apache2::Const::OK;
}

1;
