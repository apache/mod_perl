package TestModperl::getc;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

sub handler {
    my $r = shift;

    tie *STDIN, $r unless tied *STDIN;

    while (my $c = getc) {
        die "got more than 1 char" unless length($c) == 1;
        $r->puts($c);
    }

    Apache::OK;
}

1;
