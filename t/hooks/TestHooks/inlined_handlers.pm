package TestHooks::inlined_handlers;

# this test exercises httpd.conf inlined one-liner handlers, like:
#   PerlFixupHandler 'sub { use Apache2::Const qw(DECLINED); DECLINED }'
# previously there was a bug in non-ithreaded-perl implementation
# where the cached compiled CODE ref didn't have the reference count
# right.
#
# this test needs to run via the same_interpr framework, since it must
# test that the same perl interprter/process gets to run the same
# inlined handler

use strict;
use warnings FATAL => 'all';

use Apache2::RequestIO ();

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    $r->print('ok');

    Apache2::Const::OK;
}

1;
__DATA__
<NoAutoConfig>
  <Location /TestHooks__inlined_handlers>
      SetHandler modperl
      PerlInitHandler     Apache::TestHandler::same_interp_fixup
      PerlFixupHandler    'sub { use Apache2::Const qw(DECLINED); DECLINED }'
      PerlResponseHandler TestHooks::inlined_handlers
  </Location>
</NoAutoConfig>
