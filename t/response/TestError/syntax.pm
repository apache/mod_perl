package TestError::syntax;

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use Apache2::Const -compile => qw(OK);

sub handler {
    my $r = shift;

    $r->content_type('text/plain');

    # the following syntax error is here on purpose!
    lkj;\;

    $r->print('ok');

    return Apache2::Const::OK;
}

1;
__END__

