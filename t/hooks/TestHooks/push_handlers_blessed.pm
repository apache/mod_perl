package TestHooks::push_handlers_blessed;

# test that we
# - can push and execute blessed anon handlers

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

    plan $r, tests => 1;

    my $sub = sub {
        ok 1;

        return Apache::OK;
    };

    my $handler = bless $sub, __PACKAGE__;

    $r->push_handlers(PerlResponseHandler => $handler);

    return Apache::DECLINED;
}

1;
__DATA__
<NoAutoConfig>
<Location /TestHooks__push_handlers_blessed>
    SetHandler modperl
    PerlResponseHandler TestHooks::push_handlers_blessed
</Location>
</NoAutoConfig>
