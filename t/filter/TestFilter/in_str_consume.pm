package TestFilter::in_str_consume;

# this test verifies that streaming filters framework handles
# gracefully the case when a filter doesn't print anything at all to
# the caller. I figure it absolutely doesn't matter if the incoming
# bb from the upstream is consumed or not. What matters is that the
# filter sends something downstream (an empty bb will do).
#
# the real problem is that in the streaming filters we can't consume
# more than one bucket brigade, which we can in non-stream filters.,
# e.g. see in_bbs_underrun.pm
#
# e.g. a filter that cleans up the incoming stream (extra spaces?)
# might reduce the whole bb into nothing (e.g. if it was made of only
# white spaces) then it should send "" down.
#
# another problem with not reading in the while() loop, is that the
# eos bucket won't be detected by the streaming framework and
# consequently won't be sent downstream, probably breaking other
# filters who rely on receiving the EOS bucket.

use strict;
use warnings FATAL => 'all';

use Apache::Filter ();

use Apache::Const -compile => qw(OK M_POST);

sub handler {
    my $filter = shift;

    my $count = $filter->ctx || 0;

    unless ($count) {
        # read a bit from the first brigade and leave the second
        # brigade completely unconsumed. we assume that there are two
        # brigades because the core input filter will split data in
        # 8kb chunks per brigade and we have sent 11k of data (1st bb:
        # 8kb, 2nd bb: ~3kb)
        my $len = $filter->read(my $buffer, 1024);
        #warn "FILTER READ: $len bytes\n";
        $filter->print("read just the first 1024b from the first brigade");

        $filter->ctx(1);
    }
    else {
        $count++;
        #warn "FILTER CALLED post $count time\n";
        unless ($filter->seen_eos) {
            # XXX: comment out the next line to reproduce the segfault
            $filter->print("");
            $filter->ctx($count);
        }

        # this is not needed in newer Apache versions, however older
        # versions (2.0.40) will repeatedly call this filter, waiting
        # for EOS which will never come from this filter so, after
        # several invocations mark the seen_eos flag, to break the
        # vicious cirle
        if ($count > 10) {
            $filter->seen_eos(1);
        }
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

    return Apache::OK;
}
1;
__DATA__
SetHandler modperl
PerlModule          TestFilter::in_str_consume
PerlResponseHandler TestFilter::in_str_consume::response
