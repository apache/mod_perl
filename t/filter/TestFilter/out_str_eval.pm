package TestFilter::out_str_eval;

# at some point there was a problem when eval {} in a non-filter
# handler wasn't functioning when a filter was involved. the $@ value
# was getting lost when t_cmp was doing print of debug values. and a
# new invocation of a filter handler resets the value of $@.

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::Filter ();

use Apache::Test;
use Apache::TestUtil;

use Apache::Const -compile => qw(OK DECLINED);

# dummy pass_through filter was good enough to trigger the problem
sub handler {
    return Apache::DECLINED;
}

sub response {
    my $r = shift;

    plan $r, tests => 1, todo => [1];
    # XXX: see if we can fix filter handlers to restore the original
    # $@ when the callback completes
    eval { i_do_not_exist_really_i_do_not() };
    # trigger the filter invocation, before using $@
    $r->print("# whatever");
    $r->rflush;
    ok t_cmp($@, qr/Undefined subroutine/, "some croak");

    return Apache::OK;
}

1;
__DATA__
SetHandler modperl
PerlModule          TestFilter::out_str_eval
PerlResponseHandler TestFilter::out_str_eval::response

