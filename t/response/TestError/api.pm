package TestError::api;

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => qw(OK);

sub handler {
    my $r = shift;

    plan $r, tests => 1;

    $r->content_type('text/plain');

    # PerlOptions -GlobalRequest is in effect
    eval { my $gr = Apache->request; };
    ok t_cmp($@, 
             qr/\$r object is not available/,
             "unavailable global $r object");

    return Apache2::OK;
}

1;
__END__
PerlOptions -GlobalRequest
