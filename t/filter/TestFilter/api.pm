package TestFilter::api;

use strict;
use warnings FATAL => 'all';

use Apache::Filter ();
use Apache::FilterRec ();

use Test;

my $response_data = "blah blah blah";

sub init_test_pm {
    my $filter = shift;

    {
        package Apache::Filter;
        #XXX: make part of standard api?
        unless (defined &PRINT) {
            *PRINT = \&print;
            *TIEHANDLE = sub { shift };
        }
    }

    tie *STDOUT, $filter;

    $Test::TESTOUT = \*STDOUT;
    $Test::planned = 0;
    $Test::ntest = 1;
}

sub handler {
    my $filter = shift;

    $filter->read(my $buffer); #slurp everything;

    init_test_pm($filter);

    plan tests => 6;

    ok $buffer eq $response_data;

    ok $filter->isa('Apache::Filter');

    my $frec = $filter->frec;

    ok $frec->isa('Apache::FilterRec');

    ok $frec->name;

    my $r = $filter->r;

    ok $r->isa('Apache::RequestRec');

    ok $r->uri eq '/' . __PACKAGE__;

    0;
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
