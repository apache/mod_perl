package TestFilter::in_bbs_inject_header;

# this filter demonstrates two things:
# 1. how to write a filter that will work only on HTTP headers
# 2. how to inject extra HTTP headers
#
# the first task is simple -- as soon as a bucket which matches
# /^[\r\n]+$/ is read we can store that event in the filter context and
# simply 'return Apache::DECLINED on the future invocation, so not to
# slow things.
#
#
# the second task is a bit trickier, as the headers_in core httpd
# filter is picky and it wants each header to arrive in a separate
# bucket, and moreover this bucket needs to be in its own brigade.
# so this test arranges for this to happen.
#
# the test shows how to push headers at the end of all headers
# and in the middle, whichever way you prefer.

use strict;
use warnings FATAL => 'all';

use base qw(Apache::Filter);

use Apache::RequestRec ();
use Apache::RequestIO ();
use APR::Brigade ();
use APR::Bucket ();

use Apache::Test;
use Apache::TestUtil;
use Apache::TestTrace;

use Apache::Const -compile => qw(OK DECLINED);
use APR::Const    -compile => ':common';

my $header1_key = 'X-My-Protocol';
my $header1_val = 'POST-IT';

my %headers = (
    'X-Extra-Header2' => 'Value 2',
    'X-Extra-Header3' => 'Value 3',
);

my $request_body = "This body shouldn't be seen by the filter";

# returns 1 if a bucket with a header was inserted to the $bb's tail,
# otherwise returns 0 (i.e. if there are no buckets to insert)
sub inject_header_bucket {
    my ($bb, $ctx) = @_;

    return 0 unless @{ $ctx->{buckets} };

    my $bucket = shift @{ $ctx->{buckets} };
    $bb->insert_tail($bucket);

    if (1) {
        # extra debug, wasting cycles
        my $data;
        $bucket->read($data);
        debug "injected header: [$data]";
    }
    else {
        debug "injected header";
    }

    # next filter invocations will bring the request body if any
    if ($ctx->{seen_body_separator} && !@{ $ctx->{buckets} }) {
        $ctx->{done_with_headers}   = 1;
        $ctx->{seen_body_separator} = 0;
    }

    return 1;
}

sub handler : FilterConnectionHandler {
    my($filter, $bb, $mode, $block, $readbytes) = @_;

    debug join '', "-" x 20 , " filter called ", "-" x 20;

    my $ctx;
    unless ($ctx = $filter->ctx) {
        debug "filter context init";
        $ctx = {
            buckets             => [],
            done_with_headers   => 0,
            seen_body_separator => 0,
        };
        # since we are going to manipulate the reference stored in
        # ctx, it's enough to store it only once, we will get the same
        # reference in the following invocations of that filter
        $filter->ctx($ctx);
    }

    # handling the HTTP request body
    if ($ctx->{done_with_headers}) {
        # XXX: when the bug in httpd filter will be fixed all the
        # code in this branch will be replaced with:
        #   $filter->remove;
        #   return Apache::DECLINED;
        # at the moment (2.0.48) it doesn't work
        # so meanwhile tell the mod_perl filter core to pass-through
        # the brigade unmodified
        debug "passing the body through unmodified";
        return Apache::DECLINED;
    }

    # any custom HTTP header buckets to inject?
    return Apache::OK if inject_header_bucket($bb, $ctx);

    # normal HTTP headers processing
    my $c = $filter->c;
    my $ctx_bb = APR::Brigade->new($c->pool, $c->bucket_alloc);
    my $rv = $filter->next->get_brigade($ctx_bb, $mode, $block, $readbytes);
    return $rv unless $rv == APR::SUCCESS;

    while (!$ctx_bb->empty) {
        my $data;
        my $bucket = $ctx_bb->first;

        $bucket->remove;

        if ($bucket->is_eos) {
            debug "EOS!!!";
            $bb->insert_tail($bucket);
            last;
        }

        my $status = $bucket->read($data);
        debug "filter read:\n[$data]";
        return $status unless $status == APR::SUCCESS;

        # check that we really work only on the headers
        die "This filter should not ever receive the request body, " .
            "but HTTP headers" if ($data||'') eq $request_body;

        if ($data and $data =~ /^POST/) {
            # demonstrate how to add a header while processing other headers
            my $header = "$header1_key: $header1_val\n";
            push @{ $ctx->{buckets} }, APR::Bucket->new($header);
            debug "queued header [$header]";
        }
        elsif ($data =~ /^[\r\n]+$/) {
            # normally the body will start coming in the next call to
            # get_brigade, so if your filter only wants to work with
            # the headers, it can decline all other invocations if that
            # flag is set. However since in this test we need to send 
            # a few extra bucket brigades, we will turn another flag
            # 'done_with_headers' when 'seen_body_separator' is on and
            # all headers were sent out
            debug "END of original HTTP Headers";
            $ctx->{seen_body_separator}++;

            # we hit the headers and body separator, which is a good
            # time to add extra headers:
            for my $key (keys %headers) {
                my $header = "$key: $headers{$key}\n";
                push @{ $ctx->{buckets} }, APR::Bucket->new($header);
                debug "queued header [$header]";
            }

            # but at the same time we must ensure that the
            # the separator header will be sent as a last header
            # so we send one newly added header and push the separator
            # to the end of the queue
            push @{ $ctx->{buckets} }, $bucket;
            debug "queued header [$data]";
            inject_header_bucket($bb, $ctx);
            next; # inject_header_bucket already called insert_tail
            # notice that if we didn't inject any headers, this will
            # still work ok, as inject_header_bucket will send the
            # separator header which we just pushed to its queue
        }
        else {
            # fall through
        }

        $bb->insert_tail($bucket);
    }

    return Apache::OK;
}

sub response {
    my $r = shift;

    my $data = ModPerl::Test::read_post($r);

    plan $r, tests => 2 + keys %headers;

    ok t_cmp($request_body, $data);

    ok t_cmp($header1_val,
             $r->headers_in->get($header1_key),
             "injected header $header1_key");

    for my $key (sort keys %headers) {
        ok t_cmp($headers{$key},
                 $r->headers_in->get($key),
                 "injected header $key");
    }

    Apache::OK;
}

1;
__END__
<NoAutoConfig>
<VirtualHost TestFilter::in_bbs_inject_header>
  # must be preloaded so the FilterConnectionHandler attributes will
  # be set by the time the filter is inserted into the filter chain
  PerlModule TestFilter::in_bbs_inject_header
  PerlInputFilterHandler TestFilter::in_bbs_inject_header
  <Location /TestFilter__in_bbs_inject_header>
     SetHandler modperl
     PerlResponseHandler TestFilter::in_bbs_inject_header::response
  </Location>

</VirtualHost>
</NoAutoConfig>
