package TestModperl::io_with_closed_stds;

# test that we can successfully override STD(IN|OUT) for
# 'perl-script', even if they are closed.

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestUtil ();
use Apache::RequestIO ();
use Apache::SubRequest ();

use Apache::Test;

use Apache::Const -compile => 'OK';

sub fixup {
    my $r = shift;

    # we must close STDIN as well, due to a perl bug (5.8.0 - 5.8.3
    # w/useperlio), which emits a warning if dup is called with
    # one of the STD streams is closed.
    open my $oldin,  "<&STDIN"  or die "Can't dup STDIN: $!";
    open my $oldout, ">&STDOUT" or die "Can't dup STDOUT: $!";
    close STDIN;
    close STDOUT;
    $r->pnotes(oldin  => $oldin);
    $r->pnotes(oldout => $oldout);

    Apache::OK;
}

sub handler {
    my $r = shift;

    plan $r, tests => 1;

    ok 1;

    Apache::OK;
}

sub cleanup {
    my $r = shift;

    # restore the STD(IN|OUT) streams so not to affect other tests.
    my $oldin  = $r->pnotes('oldin');
    my $oldout = $r->pnotes('oldout');
    open STDIN,  "<&", $oldin  or die "Can't dup \$oldin: $!";
    open STDOUT, ">&", $oldout or die "Can't dup \$oldout: $!";
    close $oldin;
    close $oldout;

    Apache::OK;
}

1;
__DATA__
PerlModule TestModperl::io_with_closed_stds
SetHandler perl-script
PerlFixupHandler    TestModperl::io_with_closed_stds::fixup
PerlResponseHandler TestModperl::io_with_closed_stds
PerlCleanupHandler  TestModperl::io_with_closed_stds::cleanup
