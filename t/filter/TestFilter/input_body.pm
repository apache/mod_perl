package TestFilter::input_body;

use strict;
use warnings FATAL => 'all';

use base qw(Apache::Filter); #so we inherit MODIFY_CODE_ATTRIBUTES

use Test;
use Apache::Test ();
use Apache::Const -compile => qw(M_POST);
use APR::Const -compile => ':common';
use APR::Brigade ();
use APR::Bucket ();

#XXX
@Apache::InputFilter::ISA = qw(Apache::OutputFilter);

sub handler : InputFilterBody {
    my($filter, $bb, $mode) = @_;

    if ($bb->empty) {
        my $rv = $filter->f->next->get_brigade($bb, $mode);

        if ($rv != APR::SUCCESS) {
            return $rv;
        }
    }

    for (my $bucket = $bb->first; $bucket; $bucket = $bb->next($bucket)) {
        my $data;
        my $status = $bucket->read($data);

        $bucket->remove;
        if ($data) {
            $bb->insert_tail(APR::Bucket->new(scalar reverse $data));
        }
        else {
            #maintain EOS bucket
            $bb->insert_tail($bucket);
        }
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
