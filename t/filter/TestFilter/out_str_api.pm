package TestFilter::out_str_api;

# Test Apache::FilterRec and Apache::Filter accessors

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::Filter ();
use Apache::FilterRec ();

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

use Apache::Const -compile => 'OK';

my $response_data = "blah blah blah";

#XXX: else pp_untie complains:
#untie attempted while %d inner references still exist
sub Apache::Filter::UNTIE {}
sub Apache::Filter::PRINTF {}

sub handler {
    my $filter = shift;

    my $data = '';
    while ($filter->read(my $buffer, 1024)) {
        $data .= $buffer;
    }

    tie *STDOUT, $filter;

    plan tests => 8;

    ok t_cmp($response_data, $data, "response data");

    ok $filter->isa('Apache::Filter');

    {
        my $frec = $filter->frec;

        ok $frec->isa('Apache::FilterRec');
        ok t_cmp("modperl_request_output", $frec->name, '$frec->name');

        my $next = $filter->next;
        ok t_cmp("modperl_request_output",
                 $next->frec->name, '$filter->next->frec->name');

        $next = $next->next;
        # since we can't ensure that the next filter will be the same,
        # as it's not under control, just check that we get some name
        my $name = $next->frec->name;
        t_debug("next->next name: $name");
        ok $name;
    }

    my $r = $filter->r;

    ok $r->isa('Apache::RequestRec');

    my $path = '/' . Apache::TestRequest::module2path(__PACKAGE__);
    ok t_cmp($path, $r->uri, "path");

    untie *STDOUT;

    # we have done the job
    $filter->remove;

    Apache::OK;
}

sub pass_through {
    return Apache::DECLINED;
}

sub response {
    my $r = shift;

    $r->content_type('text/plain');
    $r->puts($response_data);

    Apache::OK;
}

1;
__DATA__
<NoAutoConfig>
PerlModule TestFilter::out_str_api
<Location /TestFilter__out_str_api>
    SetHandler modperl
    PerlResponseHandler TestFilter::out_str_api::response
    PerlOutputFilterHandler TestFilter::out_str_api
    PerlOutputFilterHandler TestFilter::out_str_api::pass_through
</Location>
</NoAutoConfig>
