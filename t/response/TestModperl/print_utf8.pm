package TestModperl::print_utf8;

use strict;
use warnings FATAL => 'all';

use Apache::RequestIO ();
use Apache::RequestRec ();

use Apache::Const -compile => 'OK';

use utf8;

sub handler {
    my $r = shift;

    $r->content_type('text/plain; charset=UTF-8');

    #Apache::RequestRec::BINMODE
    binmode(STDOUT, ':utf8');

    # must be non-$r->print(), so we go through the tied STDOUT
    print "Hello Ayhan \x{263A} perlio rules!";

    Apache::OK;
}

1;
__DATA__
# must test against a tied STDOUT
SetHandler perl-script
