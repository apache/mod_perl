package TestFilter::reverse;

use strict;
use warnings FATAL => 'all';

use Apache::Filter ();

sub handler {
    my $filter = shift;

    while ($filter->read(my $buffer, 1024)) {
        $filter->print(scalar reverse $buffer);
    }

    0;
}

sub response {
    my $r = shift;

    $r->content_type('text/plain');
    $r->puts(scalar reverse "1..1\n");
    $r->puts(scalar reverse "ok 1\n");

    0;
}

1;
__DATA__
SetHandler modperl
PerlResponseHandler TestFilter::reverse::response
