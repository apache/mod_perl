package TestFilter::input_body;

use strict;
use warnings FATAL => 'all';

use base qw(Apache::Filter); #so we inherit MODIFY_CODE_ATTRIBUTES

use Apache::Const -compile => qw(M_POST);
use APR::Const -compile => ':common';
use APR::Brigade ();
use APR::Bucket ();

sub handler : FilterRequestHandler {
    my($filter, $bb, $mode, $readbytes) = @_;

    my $ctx_bb = APR::Brigade->new($filter->r->pool);

    my $rv = $filter->next->get_brigade($ctx_bb, $mode, $readbytes);

    if ($rv != APR::SUCCESS) {
        return $rv;
    }

    while (!$ctx_bb->empty) {
        my $data;
        my $bucket = $ctx_bb->first;

        $bucket->remove;

        if ($bucket->is_eos) {
            $bb->insert_tail($bucket);
            last;
        }

        my $status = $bucket->read($data);

        if ($status != APR::SUCCESS) {
            return $status;
        }

        if ($data) {
            $bucket = APR::Bucket->new(scalar reverse $data);
        }

        $bb->insert_tail($bucket);
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
PerlResponseHandler TestFilter::input_body::response
