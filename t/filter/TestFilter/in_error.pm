package TestFilter::in_error;

# errors in filters should be properly propogated to httpd

# XXX: need to test output as well, and separately connection and
# request filters

use strict;
use warnings FATAL => 'all';

use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::Filter ();
use APR::Table ();

use Apache::TestTrace;
use Apache::TestUtil;

use Apache::Const -compile => qw(OK);

sub handler {
    my $filter = shift;

    debug join '', "-" x 20 , " filter called ", "-" x 20;

    t_server_log_error_is_expected();
    die "This filter must die";

    return Apache::OK;
}

sub response {
    my $r = shift;

    my $len = $r->read(my $data, $r->headers_in->{'Content-Length'});
    t_server_log_error_is_expected();
    die "failed to read POSTed data: $!" unless defined $len;
    debug "read $len bytes [$data]";

    $r->content_type('text/plain');
    $r->print("it shouldn't be printed, because the input filter has died");

    Apache::OK;
}
1;
__DATA__
SetHandler modperl
PerlModule          TestFilter::in_error
PerlResponseHandler TestFilter::in_error::response
