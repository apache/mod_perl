package TestFilter::api;

use strict;
use warnings FATAL => 'all';

use Apache::Filter ();
use Apache::FilterRec ();

use Apache::Test;

my $response_data = "blah blah blah";

#XXX: else pp_untie complains:
#untie attempted while %d inner references still exist
sub Apache::Filter::UNTIE {}

sub handler {
    my $filter = shift;

    $filter->read(my $buffer); #slurp everything;

    tie *STDOUT, $filter;

    plan tests => 6;

    ok $buffer eq $response_data;

    ok $filter->isa('Apache::Filter');

    my $frec = $filter->frec;

    ok $frec->isa('Apache::FilterRec');

    ok $frec->name;

    my $r = $filter->r;

    ok $r->isa('Apache::RequestRec');

    ok $r->uri eq '/' . __PACKAGE__;

    untie *STDOUT;

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
PerlResponseHandler TestFilter::api::response
