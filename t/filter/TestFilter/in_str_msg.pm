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
my $to_url = '/TestFilter__in_str_msg';

sub handler : FilterConnectionHandler {
    my $filter = shift;

    #warn "FILTER CALLED\n";
    my $ctx = $filter->ctx;

    while ($filter->read(my $buffer, 1024)) {
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
  PerlModule TestFilter::in_str_msg
  PerlInputFilterHandler TestFilter::in_str_msg

  <Location /TestFilter__in_str_msg>
     SetHandler modperl
     PerlResponseHandler TestFilter::in_str_msg::response
  </Location>

</VirtualHost>
