package TestCompat::send_fd;

use strict;
use warnings FATAL => 'all';

use Apache2::compat ();
use Apache2::RequestRec ();

use Apache2::Const -compile => ':common';

sub handler {
    my $r = shift;

    my $file = $r->args || __FILE__;

    open my $fh, $file or return Apache2::NOT_FOUND;

    my $bytes = $r->send_fd($fh);

    return Apache2::SERVER_ERROR unless $bytes == -s $file;

    Apache2::OK;
}

1;
