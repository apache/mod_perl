package TestAPI::send_fd;

use strict;
use warnings FATAL => 'all';

use Apache::compat ();

sub handler {
    my $r = shift;

    my $file = $r->args || __FILE__;

    open my $fh, $file or return Apache::NOT_FOUND;

    my $bytes = $r->send_fd($fh);

    return Apache::SERVER_ERROR unless $bytes == -s $file;

    Apache::OK;
}

1;
