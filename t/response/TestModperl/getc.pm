package TestModperl::getc;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

sub handler {
    my $r = shift;

    untie *STDIN;
    tie *STDIN, $r;

    while (my $c = getc) {
        die "got more than 1 char" unless length($c) == 1;
        $r->puts($c);
    }

    untie *STDIN;

    Apache::OK;
}

1;
