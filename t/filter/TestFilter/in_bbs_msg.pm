package TestFilter::in_bbs_msg;

use strict;
use warnings FATAL => 'all';

use base qw(Apache::Filter);

use Apache::RequestRec ();
use Apache::RequestIO ();
use APR::Brigade ();
use APR::Bucket ();

use Apache::Const -compile => 'OK';
use APR::Const -compile => ':common';

use Apache::TestTrace;

my $from_url = '/input_filter.html';
my $to_url = '/TestFilter__in_bbs_msg';

sub handler : FilterConnectionHandler {
    my($filter, $bb, $mode, $block, $readbytes) = @_;

    debug "FILTER CALLED";
    my $c = $filter->c;
    my $ctx_bb = APR::Brigade->new($c->pool, $c->bucket_alloc);

    my $rv = $filter->next->get_brigade($ctx_bb, $mode, $block, $readbytes);

    if ($rv != APR::SUCCESS) {
        return $rv;
    }

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
        debug "FILTER READ:\n$data";

        if ($status != APR::SUCCESS) {
            return $status;
        }

        if ($data and $data =~ s,GET $from_url,GET $to_url,) {
            debug "GET line rewritten to be:\n$data";
            $bucket = APR::Bucket->new($data);
            # XXX: currently a bug in httpd doesn't allow to remove
            # the first connection filter. once it's fixed adjust the test
            # to test that it was invoked only once.
            # debug "removing the filter";
            # $filter->remove; # this filter is no longer needed
        }

        $bb->insert_tail($bucket);
    }

    Apache::OK;
}

sub response {
    my $r = shift;

    $r->content_type('text/plain');

    $r->puts("1..1\nok 1\n");

    Apache::OK;
}

1;
__END__
<NoAutoConfig>
<VirtualHost TestFilter::in_bbs_msg>
  PerlModule TestFilter::in_bbs_msg
  PerlInputFilterHandler TestFilter::in_bbs_msg

  <Location /TestFilter__in_bbs_msg>
     SetHandler modperl
     PerlResponseHandler TestFilter::in_bbs_msg::response
  </Location>

</VirtualHost>
</NoAutoConfig>
