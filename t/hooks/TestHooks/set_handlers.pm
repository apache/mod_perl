package TestHooks::set_handlers;

# test various ways to reset/unset handlers list

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::RequestUtil ();

use Apache::Const -compile => qw(OK);

sub handler {
    my $r = shift;

    # the first way to reset the handlers list is to pass undef
    # access handler phase will be not called for mp
    $r->set_handlers(PerlAccessHandler => undef);

    # the second way to reset the handlers list is to pass []
    # fixup must be not executed
    $r->set_handlers(PerlFixupHandler => \&fixup);
    $r->set_handlers(PerlFixupHandler => []);

    # normal override
    $r->set_handlers(PerlResponseHandler => sub { die "not to be called"});
    $r->set_handlers(PerlResponseHandler => [\&Apache::TestHandler::ok1]);
    $r->handler("modperl");

    return Apache::OK;
}

sub fixup {
    die "fixup must not be executed";
}

1;
__DATA__
<NoAutoConfig>
  <Location /TestHooks__set_handlers>
      PerlHeaderParserHandler TestHooks::set_handlers
  </Location>
</NoAutoConfig>

