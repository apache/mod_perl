package TestFilter::in_str_consume;

# this test verifies that streaming filters framework handles
# gracefully the case when a filter doesn't print anything at all to
# the caller.

# the real problem is that in the streaming filters we can't consume
# more than one bucket brigade during a single filter invocation,
# which we can in non-stream filters., (e.g. see in_bbs_underrun.pm)
#
# it seems that this works just fine (2.0.46+) and older httpds
# had problems when a filter invocation hasn't printed a thing.
#
# currently if the streaming filter doesn't print anything, the
# upstream filter gets an empty brigade brigade (easily verified with
# the snooping debug filter). Of course if the filter returns
# Apache::DECLINED the unconsumed data will be passed to upstream filter
#
# this test receives about 10 bbs
# it reads only the first 23 bytes of each bb and discards the rest
# since it wants only 105 bytes it partially consumes only the first 5 bbs
# since it doesn't read all the data in, it'll never see EOS
# therefore once it has read all 105 bytes, it manually sets the EOS flag
# and the rest of the bbs are ignored, the filter is invoked only 5 times
#
# to debug this filter run it as:
#
# t/TEST -v -trace=debug filter/in_str_consume
#
# to enable upstream and downstream filter snooping, uncomment the
# snooping filters directives at the end of this file and rerun:
# t/TEST -conf
#
# to see what happens inside the filter, assuming that you built
# mod_perl with MP_TRACE=1, run:
# env MOD_PERL_TRACE=f t/TEST -v -trace=debug filter/in_str_consume
#

use strict;
use warnings FATAL => 'all';

use Apache::Filter ();
use Apache::TestTrace;

use Apache::Const -compile => qw(OK M_POST);

use constant READ_BYTES_TOTAL => 105;
use constant READ_BYTES_FIRST => 23;

sub handler {
    my $filter = shift;

    my $ctx = $filter->ctx || { data => '', count => '1'};
    debug "FILTER INVOKED: $ctx->{count}";

    # read untill READ_BYTES read, no matter how many filter
    # invocations it'll take
    my $wanted_total   = READ_BYTES_TOTAL - length $ctx->{data};
    my $wanted_current = READ_BYTES_FIRST;
    my $wanted = $wanted_total;
    $wanted = $wanted_current if $wanted > $wanted_current;
    debug "total wanted:   $wanted_total bytes";
    debug "this bb wanted: $wanted bytes";
    while ($wanted) {
        my $len = $filter->read(my $buffer, $wanted);
        $ctx->{data} .= $buffer;
        $wanted_total -= $len;
        $wanted       -= $len;
        debug "FILTER READ: $len ($wanted_total more to go)";
        last unless $len; # no more data to read in this bb
    }

    $ctx->{count}++;

    unless ($wanted_total) {
        # we don't want to read the rest if there is anything left
        $filter->seen_eos(1);
    }

    if ($filter->seen_eos) {
        # flush the data if we are done
        $filter->print($ctx->{data});
    }
    else {
        # store the data away
        $filter->ctx($ctx);

        # notice that it seems to work even though we don't print
        # anything. the upstream filter gets an empty bb.

        # alternatively could print the chunks of data that we read,
        # if we don't need to have it as a whole chunk
    }

    return Apache::OK;
}

sub response {
    my $r = shift;

    $r->content_type('text/plain');

    if ($r->method_number == Apache::M_POST) {
        my $data = ModPerl::Test::read_post($r);
        my $len = length $data;
        debug "HANDLER READ: $len bytes\n";
        $r->print($len);
    }

    return Apache::OK;
}
1;
__DATA__
SetHandler modperl
PerlModule          TestFilter::in_str_consume
PerlResponseHandler TestFilter::in_str_consume::response
#PerlInputFilterHandler  ModPerl::TestFilterDebug::snoop_request
PerlInputFilterHandler  TestFilter::in_str_consume::handler
#PerlInputFilterHandler  ModPerl::TestFilterDebug::snoop_request
