use strict;
use warnings FATAL => 'all';

#
# there is a problem when STDOUT is internally opened to an
# Apache::PerlIO layer is cloned on a new thread start. PerlIO_clone
# in perl_clone() is called too early, before PL_defstash is
# cloned. As PerlIO_clone calls PerlIOApache_getarg, which calls
# gv_fetchpv via sv_setref_pv and boom the segfault happens.
#
# at the moment we should either not use an internally opened to
# :Apache streams, so the config must be:
#
# SetHandler modperl
#
# and then either use $r->print("foo") or tie *STDOUT, $r + print "foo"
#
# or close and re-open STDOUT to :Apache *after* the thread was spawned
#
# the above discussion equally applies to STDIN
#
# XXX: ->join calls leak under registry, this doesn't happen in the
# non-registry tests.

use threads;

my $r = shift;
$r->print("Content-type: text/plain\n\n");

{
    # now we can use $r->print API:
    my $thr = threads->new(
        sub {
            my $id = shift;
            $r->print("thread $id\n");
            return 1;
        }, 1);
    # $thr->join; # XXX: leaks scalar
}

{
    # close and re-open STDOUT to :Apache *after* the thread was
    # spawned
    my $thr = threads->new(
        sub {
            my $id = shift;
            close STDOUT;
            open STDOUT, ">:Apache", $r
                or die "can't open STDOUT via :Apache layer : $!";
            print "thread $id\n";
            return 1;
        }, 2);
    # $thr->join; # XXX: leaks scalar
}

{
    # tie STDOUT to $r *after* the ithread was started has
    # happened, in which case we can use print
    my $thr = threads->new(
        sub {
            my $id = shift;
            tie *STDOUT, $r;
            print "thread $id\n";
            return 1;
        }, 3);
    # $thr->join; # XXX: leaks scalar
}

{
    # tie STDOUT to $r before the ithread was started has
    # happened, in which case we can use print
    tie *STDOUT, $r;
    my $thr = threads->new(
        sub {
            my $id = shift;
            print "thread $id\n";
            return 1;
        }, 4);
    # $thr->join; # XXX: leaks scalar
}

print "parent";
