package TestAPI::sendfile;

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();

use APR::Const -compile => 'SUCCESS';
use Apache::Const -compile => ':common';

sub handler {
    my $r = shift;

    $r->content_type('text/plain');
    my $file = $r->args || __FILE__;

    # buffer output up, so we can test that sendfile flushes any
    # buffered output before sending the file contents out
    local $|;
    $r->print("This is a header\n")
        unless $file eq 'noexist-n-noheader.txt';

    my $rc = $r->sendfile($file);
    unless ($rc == APR::SUCCESS) {
        # warn APR::Error::strerror($rc);
        return $file eq 'noexist-n-noheader.txt'
            ? Apache::NOT_FOUND
            : $rc;
    }

    $r->print("This is a footer\n");

    return Apache::OK;
}

1;
