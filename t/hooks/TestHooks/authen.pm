package TestHooks::authen;

use strict;
use warnings FATAL => 'all';

use Apache::Access ();

sub handler {
    my $r = shift;
    #auth api not complete yet
    0;
}

1;
__DATA__
require valid-user
AuthType Basic
AuthName simple
PerlResponseHandler Apache::TestHandler::ok1
SetHandler modperl
