package TestFilter::in_str_lc;

use strict;
use warnings FATAL => 'all';

use Apache::Filter ();

use Apache::Const -compile => qw(OK M_POST);

sub handler {
     my($filter, $bb, $mode, $block, $readbytes) = @_;

    while ($filter->read($mode, $block, $readbytes, my $buffer, 1024)) {
        #warn "FILTER READ: $buffer\n";
        $filter->print(lc $buffer);
    }

    return Apache::OK;
}

sub response {
    my $r = shift;

    $r->content_type('text/plain');

    if ($r->method_number == Apache::M_POST) {
        my $data = ModPerl::Test::read_post($r);
        #warn "HANDLER READ: $data\n";
        $r->print($data);
    }

    Apache::OK;
}
1;
__DATA__
SetHandler modperl
PerlResponseHandler TestFilter::in_str_lc::response
