package TestModperl::print;

use strict;
use warnings FATAL => 'all';

use Apache::RequestIO ();

use Apache::Test;

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    plan $r, tests => 6;

    binmode STDOUT; #Apache::RequestRec::BINMODE (noop)

    ok 1;

    ok 2;

    {
        # print should return true on success, even
        # if it sends no data.
        my $rc = print '';

        ok ($rc);
        ok ($rc == 0);  # 0E0 is still numerically 0
    }

    {
        my $rc = print "# 11 bytes\n";  # don't forget the newline

        ok ($rc == 11);
    }

    printf "ok %d\n", 6;

    Apache::OK;
}

END {
    my $package = __PACKAGE__;
    warn "END in $package, pid=$$\n";
}

1;
