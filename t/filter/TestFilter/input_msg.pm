package TestFilter::input_msg;

use strict;
use warnings FATAL => 'all';

use base qw(Apache::Filter);

use Test;
use Apache::Test ();
use APR::Brigade ();
use APR::Bucket ();

my $from_url = '/input_filter.html';
my $to_url = '/TestFilter::input_msg::response';

sub handler : FilterConnectionHandler {
    my($filter, $bb, $mode, $readbytes) = @_;

    my $ctx_bb = APR::Brigade->new($filter->c->pool);

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

  PerlInputFilterHandler TestFilter::input_msg

  <Location /TestFilter::input_msg::response>
     SetHandler modperl
     PerlResponseHandler TestFilter::input_msg::response
  </Location>

</VirtualHost>
