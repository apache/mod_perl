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

sub handler : InputFilterMessage {
    my($filter, $bb, $mode) = @_;

    if ($bb->empty) {
        my $rv = $filter->next->get_brigade($bb, $mode);

        if ($rv != APR::SUCCESS) {
            return $rv;
        }
    }

    for (my $bucket = $bb->first; $bucket; $bucket = $bb->next($bucket)) {
        my $data;
        my $status = $bucket->read($data);

        $bucket->remove;

        if ($data and $data =~ s,GET $from_url,GET $to_url,) {
            $bb->insert_tail(APR::Bucket->new($data));
        }
        else {
            $bb->insert_tail($bucket);
        }
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
__DATA__
<VirtualHost TestFilter::input_msg>

  PerlInputFilterHandler TestFilter::input_msg

  <Location /TestFilter::input_msg::response>
     SetHandler modperl
     PerlResponseHandler TestFilter::input_msg::response
  </Location>

</VirtualHost>
