package TestError::syntax;

BEGIN {
    use Apache::TestUtil;
    t_server_log_error_is_expected();
}

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();

use Apache::Const -compile => qw(OK);

sub handler {
    my $r = shift;

    $r->content_type('text/plain');

    # the following syntax error is here on purpose!
    lkj;\;

    $r->print('ok');

    return Apache::OK;
}

1;
__END__

