package TestHooks::trans;

use strict;
use warnings FATAL => 'all';

my %trans = (
    '/TestHooks/trans.pm' => sub {
        my $r = shift;
        $r->filename(__FILE__);
        Apache::OK;
    },
    '/phooey' => sub {
        shift->uri('/TestHooks::trans');
        Apache::OK;
    },
);

sub handler {
    my $r = shift;

    my $handler = $trans{ $r->uri };

    return Apache::DECLINED unless $handler;

    $handler->($r);
}

1;
__DATA__
PerlResponseHandler Apache::TestHandler::ok1
SetHandler modperl
