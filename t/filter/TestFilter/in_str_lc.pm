package TestFilter::in_str_lc;

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::Filter ();

use TestCommon::Utils ();

use Apache::Const -compile => qw(OK M_POST);

sub handler {
    my $filter = shift;

    while ($filter->read(my $buffer, 1024)) {
        #warn "FILTER READ: $buffer\n";
        $filter->print(lc $buffer);
    }

    return Apache::OK;
}

sub response {
    my $r = shift;

    $r->content_type('text/plain');

    if ($r->method_number == Apache::M_POST) {
        my $data = TestCommon::Utils::read_post($r);
        #warn "HANDLER READ: $data\n";
        $r->print($data);
    }

    Apache::OK;
}
1;
__DATA__
SetHandler modperl
PerlModule          TestFilter::in_str_lc
PerlResponseHandler TestFilter::in_str_lc::response
