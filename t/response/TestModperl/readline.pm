package TestModperl::readline;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::compat (); #XXX

sub handler {
    my $r = shift;

    untie *STDIN;
    tie *STDIN, $r;

    while (defined(my $line = <STDIN>)) {
        $r->puts($line);
    }

    Apache::OK;
}

1;
