package TestAPI::sub_request;

# basic subrequest tests

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::SubRequest ();

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => qw(OK SERVER_ERROR);

my $uri = '/' . Apache::TestRequest::module2path(__PACKAGE__);

sub handler {
    my $r = shift;

    my $args = $r->args || '';
    return Apache2::SERVER_ERROR if $args eq 'subreq';

    plan $r, tests => 4;

    my $subr = $r->lookup_uri("$uri?subreq");
    ok $subr->isa('Apache2::SubRequest');

    ok t_cmp $subr->uri, $uri, "uri";

    my $rc = $subr->run;
    ok $rc, Apache2::SERVER_ERROR, "rc";

    # test an explicit DESTROY (which happens automatically on the
    # scope exit)
    undef $subr;
    ok 1;

    Apache2::OK;
}

1;
__DATA__

