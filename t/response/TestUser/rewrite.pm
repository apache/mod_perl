package TestUser::rewrite;

# test here the technique of rewriting the URI namespace and
# pushing/changing the query string (args). Note that in this test we
# use a custom maptostorage handler so Apache won't complain that we
# didn't set r->filename in the core maptostorage handler. the custom
# handler simply shortcuts that phase, with the added benefit of
# skipping the ap_directory_walk's stat() calls which speeds up the
# whole thing.
#
# an alternative solution is to return Apache::DECLINED from the trans
# handler, in which case map2storage is not required (but it'll do a
# bunch of stat() calls then, which you may want to avoid)

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::URI ();

use Apache::Const -compile => qw(DECLINED OK);

my $uri_real = "/TestUser__rewrite_real";
my $args_real = "foo=bar&boo=tar";

sub trans {
    my $r = shift;

    return Apache::DECLINED unless $r->uri eq '/TestUser__rewrite';

    $r->uri($uri_real);
    $r->args($args_real);

    return Apache::OK;
}

sub map2storage {
    my $r = shift;

    return Apache::DECLINED unless $r->uri eq $uri_real;

    # skip ap_directory_walk stat() calls
    return Apache::OK;
}

sub response {
    my $r = shift;

    plan $r, tests => 1;

    my $args = $r->args();

    ok t_cmp($args, $args_real, "args");

    return Apache::OK;
}

1;
__END__
<NoAutoConfig>
    PerlModule              TestUser::rewrite
    PerlTransHandler        TestUser::rewrite::trans
    PerlMapToStorageHandler TestUser::rewrite::map2storage
    <Location /TestUser__rewrite_real>
        SetHandler modperl
        PerlResponseHandler TestUser::rewrite::response
    </Location>
</NoAutoConfig>

