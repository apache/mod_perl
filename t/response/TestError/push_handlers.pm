package TestError::push_handlers;

# This test verifies that we don't segfault when push_handlers are
# used incorrectly. Here the handler() is running under 
#   SetHandler modperl
# and it modifies its handler to be 'perl-script', plus pushes another
# handler to run. The result is that the first time handler() is run
# under the 'modperl' handler it returns declined, therefore Apache
# runs the registered 'perl-script' handler (which handler() has
# pushed in plus itself. So the handler() is executed again, followed
# by real_response(). Notice that it pushes yet another real_response
# callback onto the list of handlers. 
#
# suprisingly the response eventually works, but this is a wrong way
# to accomplish that thing. And one of the earlier stages should be
# used to push handlers. 
#
# Don't modify the handler (modperl|perl-script) during the response
# handler run-time, because if OK is not returned, the handler will be
# executed again.


use strict;
use warnings;# FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::RequestUtil ();

use Apache::Const -compile => qw(OK DECLINED);

sub handler {
    my $r = shift;

    #warn "handler called\n";

    $r->handler("perl-script");
    $r->push_handlers(PerlResponseHandler => \&real_response);

    return Apache::DECLINED;
}

sub real_response {
    my $r = shift;

    #warn "real_response called\n";

    $r->content_type('text/plain');
    $r->print('ok');

    return Apache::OK;
}

1;
__END__

