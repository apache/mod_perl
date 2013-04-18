package TestApache::read2;

# extra tests in addition to TestApache::read

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use APR::Table ();

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => qw(OK);

my $expected = "foobar";

sub handler {
    my $r = shift;

    plan $r, tests => 1;

    # test the case where the buffer to be filled has set magic
    # attached. which is the case when one passes an non-existing hash
    # entry value. it's not autovivified when passed to the function
    # and it's not undef. running SetMAGIC inside read accomplishes
    # the autovivication in this particular case.
    my $data;
    my $len = $r->read($data->{buffer}, $r->headers_in->{'Content-Length'});

    ok t_cmp($data->{buffer},
             $expected,
             "reading into an autovivified hash entry");

    Apache2::Const::OK;
}
1;

