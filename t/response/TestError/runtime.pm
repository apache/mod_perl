package TestError::runtime;

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();

use Apache::TestUtil;

use Apache::Const -compile => qw(OK);

sub handler {
    my $r = shift;

    $r->content_type('text/plain');

    t_server_log_error_is_expected();
    no_such_func();

    $r->print('ok');

    return Apache::OK;
}

1;
__END__

