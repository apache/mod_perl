package TestHooks::push_handlers_same_phase;

# test that we 
# - can push handlers into the same phase that is currently running
# - cannot switch 'perl-script' to 'modperl' and vice versa once
#   inside the response phase

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::RequestUtil ();
use APR::Table ();

use Apache::Test;
use Apache::TestUtil;

use Apache::Const -compile => qw(OK DECLINED);

sub handler {
    my $r = shift;

    my $counter = $r->notes->get('counter') || 0;
    $r->notes->set(counter => $counter+1);

    $r->push_handlers(PerlResponseHandler => \&real_response);

    return Apache::DECLINED;
}

sub real_response {
    my $r = shift;

    plan $r, tests => 3;

    # test that we don't rerun all the handlers again (it should no
    # longer happen as we don't allow switching 'perl-script' <=>
    # 'modperl' on the go, but test anyway)
    my $counter = $r->notes->get('counter') || 0;
    ok t_cmp(1, $counter, 
             __PACKAGE__ . "::handler must have been called only once");

    my @handlers = @{ $r->get_handlers('PerlResponseHandler') || []};
    ok t_cmp(2,
             scalar(@handlers),
             "there should be 2 response handlers");

    # once running inside the response phase it shouldn't be possible
    # to switch from 'perl-script' to 'modperl' and vice versa
    eval { $r->handler("perl-script") };
    ok t_cmp($@, qr/Can't switch from/,
             "can't switch from 'perl-script' to 'modperl' inside " .
             "the response phase");

    return Apache::OK;
}

1;
__END__
<NoAutoConfig>
<Location /TestHooks__push_handlers_same_phase>
    SetHandler modperl
    PerlResponseHandler TestHooks::push_handlers_same_phase
</Location>
</NoAutoConfig>
