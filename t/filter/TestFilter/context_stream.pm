package TestFilter::context_stream;

use strict;
use warnings;# FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();

use APR::Brigade ();
use APR::Bucket ();

use base qw(Apache::Filter);

use Apache::Const -compile => qw(OK M_POST);
use APR::Const -compile => ':common';

use constant BLOCK_SIZE => 5003;
use constant READ_SIZE  => 1024;

sub handler {
    my $filter = shift;

    my $ctx = $filter->ctx;
    my $data = exists $ctx->{data} ? $ctx->{data} : '';
    $ctx->{invoked}++;

    while ($filter->read(my $bdata, READ_SIZE)) {
        $data .= $bdata;
        my $len = length $data;

        my $blocks = 0;
        if ($len >= BLOCK_SIZE) {
            $blocks = int($len / BLOCK_SIZE);
            $len = $len % BLOCK_SIZE;
            $data = substr $data, $blocks*BLOCK_SIZE, $len;
            $ctx->{blocks} += $blocks;
        }
        if ($blocks) {
            $filter->print("#" x $blocks);
        }
    }

    # flush the remaining data and add a statistics signature
    if ($filter->seen_eos) {
        $filter->print("$data\n") if $data;
        my $sig = join "\n", "received $ctx->{blocks} complete blocks",
            "filter invoked $ctx->{invoked} times\n";
        $filter->print($sig);
    }
    else {
        # no need to store context, since it was the last invocation
        $ctx->{data} = $data;
        $filter->ctx($ctx);
    }

    return Apache::OK;
}


sub response {
    my $r = shift;

    $r->content_type('text/plain');

    # make sure that 
    # - we send big enough data so it won't fit into one buffer
    # - use chunk size which doesn't nicely fit into a buffer size, so
    #   we have something to store in the context between filter calls

    my $blocks = 11;
    my $block_size = BLOCK_SIZE + 1;
    # embed \n, so there will be several buckets
    my $block = "x" x $block_size;
    for (1..$blocks) {
        $r->print($block);
        $r->rflush; # so the filter reads a chunk at a time
    }

    return Apache::OK;
}

1;
__DATA__

SetHandler modperl
PerlResponseHandler TestFilter::context::response

