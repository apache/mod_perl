package TestError::runtime;

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();

use Apache::Const -compile => qw(OK);

sub handler {
    my $r = shift;

    $r->content_type('text/plain');

    warn "a call to a non-existing function\n";
    no_such_func();

    $r->print('ok');

    return Apache::OK;
}

1;
__END__

