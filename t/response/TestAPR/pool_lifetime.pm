package TestAPR::pool_lifetime;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestTrace;

use Apache::RequestRec ();
use APR::Pool ();

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
