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

    $filter->next->get_brigade($bb, $mode, $block, $readbytes);

    for (my $b = $bb->first; $b; $b = $bb->next($b)) {

        last if $b->is_eos;

        if ($b->read(my $data)) {
            next unless $data =~ s|GET $from_url|GET $to_url|;
            debug "GET line rewritten to be:\n$data";
            my $nb = APR::Bucket->new($bb->bucket_alloc, $data);
            $b->insert_before($nb);
            $b->delete;
            $b = $nb;
        }

        # XXX: currently a bug in httpd doesn't allow to remove
        # the first connection filter. once it's fixed adjust the test
        # to test that it was invoked only once.
        # debug "removing the filter";
        # $filter->remove; # this filter is no longer needed
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
