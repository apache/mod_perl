package TestFilter::in_str_msg;

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
my $to_url = '/TestFilter::in_str_msg::response';

sub handler : FilterConnectionHandler {
    my($filter, $bb, $mode, $block, $readbytes) = @_;
    #warn "FILTER CALLED\n";
    my $ctx = $filter->ctx;

    while ($filter->read($mode, $block, $readbytes, my $buffer, 1024)) {
        #warn "FILTER READ: $buffer\n";
        unless ($ctx) {
            $buffer =~ s|GET $from_url|GET $to_url|;
            $ctx = 1; # done
        }
        $filter->print($buffer);
    }
    $filter->ctx($ctx) if $ctx;

    return Apache::OK;
}

sub response {
    my $r = shift;

    $r->content_type('text/plain');

    $r->puts("1..1\nok 1\n");

    Apache::OK;
}

1;
__END__
<VirtualHost TestFilter::in_str_msg>
  # must be preloaded so the FilterConnectionHandler attributes will
  # be set by the time the filter is inserted into the filter chain
  PerlModule TestFilter::in_str_msg
  PerlInputFilterHandler TestFilter::in_str_msg

  <Location /TestFilter::in_str_msg::response>
     SetHandler modperl
     PerlResponseHandler TestFilter::in_str_msg::response
  </Location>

</VirtualHost>
