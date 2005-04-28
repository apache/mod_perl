package TestPerl::ithreads_cloning;

# a few basic tests on how mp2 objects deal with cloning (used
# APR::Table and APR::Pool for the tests)
#

use strict;
use warnings FATAL => 'all';

use APR::Table ();
use APR::Pool ();

use Apache::Test;
use Apache::TestUtil;

use TestCommon::Utils;

use Devel::Peek;

use Apache2::Const -compile => 'OK';

my $pool_ext = APR::Pool->new;
my $table_ext1 = APR::Table::make($pool_ext, 10);
my $table_ext2 = APR::Table::make($pool_ext, 10);

my $threads = 2;

sub handler {
    my $r = shift;

    my $tests = 10 * (2 + $threads);
    plan $r, tests => $tests, need
        need_threads,
        {"perl >= 5.8.1 is required (this is $])" => ($] >= 5.008001)};

    require threads;
    threads->import();

    read_test();
    #Dump $pool_ext;
    #Dump $table_ext1;
    threads->new(\&read_test)->join() for 1..$threads;
    #Dump $pool_ext;
    #Dump $table_ext1;
    read_test();

    Apache2::Const::OK;
}

# 10 subtests
sub read_test {
    my $tid = threads->self()->tid();
    t_debug "tid: $tid";

    {
        # use of invalidated cloned object
        my $error_msg = q[Can't call method "set" on unblessed reference];
        eval { $table_ext1->set(1 => 2); };
        if ($tid > 0) { # child thread
            # set must fail, since $table_ext1 must have been invalidated
            ok t_cmp $@, qr/\Q$error_msg/,
                '$table_ext1 must have been invalidated';
        }
        else {
            # should work just fine for the parent "thread", which
            # created this variable
            ok !$@;
        }
    }

    {
        # use of invalidated cloned object as an argument
        my $error_msg = 'argument is not a blessed reference ' .
            '(expecting an APR::Pool derived object)';
        eval { my $table = APR::Table::make($pool_ext, 10) };
        if ($tid > 0) { # child thread
            # make() must fail, since $pool_ext must have been invalidated
            ok t_cmp $@, qr/\Q$error_msg/,
                '$pool_ext must have been invalidated';
        }
        else {
            # should work just fine for the parent "thread", which
            # created this variable
            ok !$@;
        }
    }

    {
        # this is an important test, since the thread assigns a new
        # value to the cloned $table_ext1 (since it existed before the
        # thread was started)

        my $save = $table_ext1;

        $table_ext1 = APR::Table::make(APR::Pool->new, 10);

        validate($table_ext1);

        $table_ext1 = $save;
    }

    {
        # here $table_ext2 is a private variable, so the cloned
        # variable $table_ext2 is not touched
        my $table_ext2 = APR::Table::make(APR::Pool->new, 10);

        validate($table_ext2);
    }

    return undef;
}

# 4 subtests
sub validate {
    my $t = shift;
    my $tid = threads->self()->tid();

    $t->set($_ => $_) for 1..20;
    for my $count (1..2) {
        my $expected = 20;
        my $received = $t->get(20);
        is $received, $expected, "tid: $tid: pass 1:";
        $t->set(20 => 40);
        $received = $t->get(20);
        $expected = 40;
        is $received, $expected, "tid: $tid: pass 2:";
        # reset
        $t->set(20 => 20);
    }
}

1;

__END__

