package TestFilter::reverse;

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::Filter ();

use Apache::Const -compile => qw(OK M_POST);

sub handler {
    my $filter = shift;

    while ($filter->read(my $buffer, 1024)) {
        for (split "\n", $buffer) {
            $filter->print(scalar reverse $_);
            $filter->print("\n");
        }
    }
    $filter->print("Reversed by mod_perl 2.0\n");

    return Apache::OK;
}

sub response {
    my $r = shift;

    $r->content_type('text/plain');

    if ($r->method_number == Apache::M_POST) {
        my $data = ModPerl::Test::read_post($r);
        $r->puts($data);
    }

    return Apache::OK;
}

1;
__DATA__
<Base>
    <LocationMatch "/filter/reverse.txt">
        PerlOutputFilterHandler TestFilter::reverse
    </LocationMatch>
</Base>

SetHandler modperl
PerlResponseHandler TestFilter::reverse::response

