package TestHooks::trans;

use strict;
use warnings FATAL => 'all';

use Apache::TestConfig ();

use Apache::RequestRec ();

use Apache::Const -compile => qw(OK DECLINED);

my %trans = (
    '/TestHooks/trans.pm' => sub {
        my $r = shift;
        $r->filename(__FILE__);
        Apache::OK;
    },
    '/phooey' => sub {
        my $r = shift;
        $r->filename(__FILE__); #filename is currently required
        $r->uri('/TestHooks::trans');
        Apache::OK;
    },
);

sub handler {
    my $r = shift;

    my $uri = $r->uri;

    #XXX: temp workaround, core_translate trips on :'s
    if (Apache::TestConfig::WIN32()) {
        if ($uri =~ m,^/Test[A-Z]\w+::,) {
            $r->filename(__FILE__);
            return Apache::OK;
        }
    }

    my $handler = $trans{ $uri };

    return Apache::DECLINED unless $handler;

    $handler->($r);
}

1;
__DATA__
PerlResponseHandler Apache::TestHandler::ok1
SetHandler modperl
