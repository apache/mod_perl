package TestFilter::context;

# this is the same test as TestFilter::context_stream, but uses the
# bucket brigade API

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

sub handler {
    my($filter, $bb) = @_;

    my $c = $filter->c;
    my $bb_ctx = APR::Brigade->new($c->pool, $c->bucket_alloc);

    my $ctx = $filter->ctx;
    $ctx->{invoked}++;

    my $data = exists $ctx->{data} ? $ctx->{data} : '';

    while (my $bucket = $bb->first) {
        $bucket->remove;

        if ($bucket->is_eos) {
            # flush the remainings and send a stats signature
            $bb_ctx->insert_tail(APR::Bucket->new("$data\n")) if $data;
            my $sig = join "\n", "received $ctx->{blocks} complete blocks",
                "filter invoked $ctx->{invoked} times\n";
            $bb_ctx->insert_tail(APR::Bucket->new($sig));
            $bb_ctx->insert_tail($bucket);
            last;
        }

        my $status = $bucket->read(my $bdata);
        return $status unless $status == APR::SUCCESS;

        if (defined $bdata) {
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
                $bucket = APR::Bucket->new("#" x $blocks);
                $bb_ctx->insert_tail($bucket);
            }
        }
    }

    $ctx->{data} = $data;
    $filter->ctx($ctx);

    my $rv = $filter->next->pass_brigade($bb_ctx);
    return $rv unless $rv == APR::SUCCESS;

    return Apache::OK;
}

sub handler1 {
    my $filter = shift;

    my $ctx = $filter->ctx;

    $ctx->{invoked}++;

    my ($data, $len) = (exists $ctx->{leftover} && length $ctx->{leftover})
        ? ($ctx->{leftover}, $ctx->{leftover_len})
        : ('', 0);

    while (my $read_len = $filter->read(my $buffer, 1024)) {
        $len += $read_len;
        $data .= $buffer;
        if ($len >= BLOCK_SIZE) {
            my $blocks = int($len / BLOCK_SIZE);
            warn "len $len, $read_len, blocks $blocks\n";
            $len = $len % BLOCK_SIZE;
            warn "len $len ", length($data), "\n";
            $data = substr $data, $blocks*BLOCK_SIZE, $len;
            $ctx->{blocks} += $blocks;
            $filter->print("#" x $blocks);
        }
    }

#
#    # there shouldn't be any leftovers in our test
#    if ($filter->eos) {
#        if ($len) {
#            $filter->print("?");
#        }
#        $filter->print("sig: $blocks blocks");
#    }
#    else {
        $ctx->{leftover}     = $data;
        $ctx->{leftover_len} = $len;
        $filter->ctx($ctx);
#    }

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

