package TestAPI::sendfile;

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();

use APR::Const -compile => 'SUCCESS';
use Apache::Const -compile => ':common';

sub handler {
    my $r = shift;

    my $file = $r->args || __FILE__;

    my $status = $r->sendfile($file);

    return $status == APR::SUCCESS ? Apache::OK : Apache::NOT_FOUND;
}

1;
