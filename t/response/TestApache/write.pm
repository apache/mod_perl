package TestApache::write;

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();

use Apache::Const -compile => 'OK';

use constant BUFSIZ => 512; #small for testing

sub handler {
    my $r = shift;
    $r->content_type('text/plain');

    $r->write("1..2");
    $r->write("\n", 1);

    my $ok = "ok 1\n";
    $r->write($ok, 2);
    $r->write($ok, -1, 2);

    $ok = "not ok 2\n";
    $r->write($ok, 5, 4);

    Apache::OK;
}

1;
