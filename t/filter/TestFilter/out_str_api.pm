package TestFilter::out_str_api;

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::Filter ();
use Apache::FilterRec ();

use Apache::Test;
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

    plan tests => 6;

    ok $data eq $response_data;

    ok $filter->isa('Apache::Filter');

    my $frec = $filter->frec;

    ok $frec->isa('Apache::FilterRec');

    ok $frec->name;

    my $r = $filter->r;

    ok $r->isa('Apache::RequestRec');

    my $path = '/' . Apache::TestRequest::module2path(__PACKAGE__);
    ok $r->uri eq $path;

    untie *STDOUT;

    # we have done the job
    $filter->remove;

    Apache::OK;
}

sub response {
    my $r = shift;

    $r->content_type('text/plain');
    $r->puts($response_data);

    Apache::OK;
}

1;
__DATA__
SetHandler modperl
PerlModule          TestFilter::out_str_api
PerlResponseHandler TestFilter::out_str_api::response
