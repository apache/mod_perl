package TestModperl::readline;

use strict;
use warnings FATAL => 'all';

use Apache::RequestIO ();
use Apache::compat (); #XXX

use Apache::Test;

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    untie *STDIN;
    tie *STDIN, $r;

    while (defined(my $line = <STDIN>)) {
        $r->puts($line);
    }

    untie *STDIN;

    Apache::OK;
}

1;
