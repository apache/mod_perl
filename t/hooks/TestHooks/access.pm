package TestHooks::access;

use strict;
use warnings FATAL => 'all';

use APR::Table ();
use Apache::Access ();
use Apache::RequestRec ();

use Apache::Const -compile => qw(OK FORBIDDEN);

my $allowed_ips = qr{^(10|127)\.};

sub handler {
    my $r = shift;

    my $fake_ip = $r->headers_in->get('X-Forwarded-For') || "";

    return Apache::FORBIDDEN unless $fake_ip =~ $allowed_ips;

    Apache::OK;
}

1;
__DATA__
PerlResponseHandler Apache::TestHandler::ok1
SetHandler modperl
