package TestFilter::in_bbs_body;

use strict;
use warnings FATAL => 'all';

use base qw(Apache::Filter); #so we inherit MODIFY_CODE_ATTRIBUTES

use Apache::RequestRec ();
use Apache::RequestIO ();
use APR::Brigade ();
use APR::Bucket ();

use Apache::Const -compile => qw(OK M_POST);
use APR::Const -compile => ':common';

sub handler : FilterRequestHandler {
    my($filter, $bb, $mode, $block, $readbytes) = @_;

    #warn "Called!";
    my $ba = $filter->r->connection->bucket_alloc;

    my $ctx_bb = APR::Brigade->new($filter->r->pool, $ba);

    $filter->next->get_brigade($ctx_bb, $mode, $block, $readbytes);

    while (!$ctx_bb->is_empty) {
        my $b = $ctx_bb->first;

        $b->remove;

        if ($b->is_eos) {
            #warn "EOS!!!!";
            $bb->insert_tail($b);
            last;
        }

        if ($b->read(my $data)) {
            #warn"[$data]\n";
            $b = APR::Bucket->new(scalar reverse $data);
        }

        $bb->insert_tail($b);
    }

    Apache::OK;
}

sub response {
    my $r = shift;

    $r->content_type('text/plain');

    if ($r->method_number == Apache::M_POST) {
        my $data = ModPerl::Test::read_post($r);
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
