package TestFilter::in_init_basic;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache::RequestRec ();
use Apache::RequestIO ();

use base qw(Apache::Filter);

use Apache::Const -compile => qw(OK M_POST);

use constant READ_SIZE  => 1024;


# this filter is expected to be called once
# it'll set a note, with the count
sub init : FilterInitHandler {
    my $filter = shift;

    my $ctx = $filter->ctx;
    $ctx->{init}++;
    $filter->r->notes->set(init => $ctx->{init});
    $filter->ctx($ctx);

    return Apache::OK;
}

# this filter passes the data through unmodified and sets a note
# counting how many times it was invoked
sub transparent : FilterRequestHandler
                  FilterHasInitHandler(\&init)
    {
    my ($filter, $bb, $mode, $block, $readbytes) = @_;

    my $ctx = $filter->ctx;
    $ctx->{run}++;
    $filter->r->notes->set(run => $ctx->{run});
    $filter->ctx($ctx);

    my $rv = $filter->next->get_brigade($bb, $mode, $block, $readbytes);
    return $rv unless $rv == APR::SUCCESS;

    return Apache::OK;
}

sub response {
    my $r = shift;

    $r->content_type('text/plain');

    if ($r->method_number == Apache::M_POST) {
        $r->print(ModPerl::Test::read_post($r));
    }

    my @keys = qw(init run);
    my %times = map { $_ => $r->notes->get($_)||0 } @keys;
    $r->print("$_ $times{$_}\n") for @keys;

    Apache::OK;
}
1;
__DATA__
SetHandler modperl
PerlModule             TestFilter::in_init_basic
PerlResponseHandler    TestFilter::in_init_basic::response
PerlInputFilterHandler TestFilter::in_init_basic::transparent
