package TestHooks::headerparser;

use strict;
use warnings FATAL => 'all';

use Apache::Test;

use APR::Table ();
use Apache::RequestRec ();

use Apache::Const -compile => 'OK';

sub handler {
    my $r = shift;

    $r->notes->set(headerparser => 'set');

    Apache::OK;
}

sub response {
    my $r = shift;

    plan $r, tests => 1;

    ok $r->notes->get('headerparser') eq 'set';

    Apache::OK;
}

1;
__DATA__
PerlOptions +SetupEnv
PerlResponseHandler TestHooks::headerparser::response
SetHandler modperl
