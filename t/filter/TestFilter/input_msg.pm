package TestFilter::input_msg;

use strict;
use warnings FATAL => 'all';

use base qw(Apache::Filter);

use Apache::RequestRec ();
use Apache::RequestIO ();
use APR::Brigade ();
use APR::Bucket ();

use Apache::Const -compile => 'OK';
use APR::Const -compile => ':common';

my $from_url = '/input_filter.html';
my $to_url = '/TestFilter::input_msg::response';

sub handler : FilterConnectionHandler {
    my($filter, $bb, $mode, $block, $readbytes) = @_;

    #warn "FILTER CALLED\n";
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
            #warn "EOS!!!!";
            $bb->insert_tail($bucket);
            last;
        }

        my $status = $bucket->read($data);
        #warn "FILTER READ: $data\n";

        if ($status != APR::SUCCESS) {
            return $status;
        }

        if ($data and $data =~ s,GET $from_url,GET $to_url,) {
            $bucket = APR::Bucket->new($data);
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
<VirtualHost TestFilter::input_msg>
  # must be preloaded so the FilterConnectionHandler attributes will
  # be set by the time the filter is inserted into the filter chain
  PerlModule TestFilter::input_msg
  PerlInputFilterHandler TestFilter::input_msg

  <Location /TestFilter::input_msg::response>
     SetHandler modperl
     PerlResponseHandler TestFilter::input_msg::response
  </Location>

</VirtualHost>
