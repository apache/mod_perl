package TestHooks::access;

# demonstrates the phases execution (sometimes users claim that
# PerlInitHandler is running more than once
# run with:
# t/TEST -trace=debug -v hooks/access

use strict;
use warnings FATAL => 'all';

use APR::Table ();
use Apache::Access ();
use Apache::RequestRec ();
use Apache::TestTrace;

use Apache::Const -compile => qw(OK FORBIDDEN);

my $allowed_ips = qr{^(10|127)\.};

sub handler {
    my $r = shift;

    my $fake_ip = $r->headers_in->get('X-Forwarded-For') || "";

    debug "access: " . ($fake_ip =~ $allowed_ips ? "OK\n" : "FORBIDDEN\n");

    return Apache::FORBIDDEN unless $fake_ip =~ $allowed_ips;

    Apache::OK;
}

sub fixup { debug "fixup\n"; Apache::OK }
sub init  { debug "init\n";  Apache::OK }

1;
__DATA__
<NoAutoConfig>
PerlModule TestHooks::access
<Location /TestHooks__access>
    PerlAccessHandler   TestHooks::access
    PerlInitHandler     TestHooks::access::init
    PerlFixupHandler    TestHooks::access::fixup
    PerlResponseHandler Apache::TestHandler::ok1
    SetHandler modperl
</Location>
#<Location />
#    PerlAccessHandler TestHooks::access
#</Location>
</NoAutoConfig>
