package TestAPR::pool_lifetime;

# this test verifies that if the perl pool object exceeds the
# life-span of the underlying pool struct we don't get segfaults

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();

use Apache::Const -compile => 'OK';

my $pool;

sub handler {
    my $r = shift;

    $r->print("Pong");
    $pool = $r->pool;

    Apache::OK;
}

1;
__END__
PerlFixupHandler Apache::TestHandler::same_interp_fixup
