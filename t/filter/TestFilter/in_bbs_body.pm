package TestFilter::in_bbs_body;

use strict;
use warnings FATAL => 'all';

use base qw(Apache::Filter); #so we inherit MODIFY_CODE_ATTRIBUTES

use Apache::RequestRec ();
use Apache::RequestIO ();
use APR::Brigade ();
use APR::Bucket ();

use TestCommon::Utils ();

use Apache::Const -compile => qw(OK M_POST);
use APR::Const -compile => ':common';

sub handler : FilterRequestHandler {
    my($filter, $bb, $mode, $block, $readbytes) = @_;

    $filter->next->get_brigade($bb, $mode, $block, $readbytes);

    for (my $b = $bb->first; $b; $b = $bb->next($b)) {

        last if $b->is_eos;

        if ($b->read(my $data)) {
            #warn"[$data]\n";
            my $nb = APR::Bucket->new($bb->bucket_alloc, scalar reverse $data);
            $b->insert_before($nb);
            $b->delete;
            $b = $nb;
        }
    }

    Apache::OK;
}

sub response {
    my $r = shift;

    $r->content_type('text/plain');

    if ($r->method_number == Apache::M_POST) {
        my $data = TestCommon::Utils::read_post($r);
        $r->puts($data);
    }
    else {
        $r->puts("1..1\nok 1\n");
    }

    Apache::OK;
}

1;
__DATA__
SetHandler modperl
PerlModule          TestFilter::in_bbs_body
PerlResponseHandler TestFilter::in_bbs_body::response
