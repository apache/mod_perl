package TestFilter::reverse;

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::Filter ();

use Apache::Const -compile => 'OK';

sub handler {
    my $filter = shift;

    while ($filter->read(my $buffer, 1024)) {
        for (split "\n", $buffer) {
            $filter->print(scalar reverse $_);
            $filter->print("\n");
        }
    }

    0;
}

sub response {
    my $r = shift;

    $r->content_type('text/plain');
    $r->puts(scalar reverse "1..1\n");
    $r->puts(scalar reverse "ok 1\n");

    Apache::OK;
}

1;
__DATA__
SetHandler modperl
PerlResponseHandler TestFilter::reverse::response
