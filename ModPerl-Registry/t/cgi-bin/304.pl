use APR::Date ();
use Apache::Util ();
use Apache::RequestRec ();

use strict;
use warnings FATAL => 'all';

use constant FMT => '%a, %d %b %Y %H:%M:%S %Z';
use constant GMT => 1;

my $last_modified = "Sun, 29 Oct 2000 15:43:29 GMT";

my $r = shift;

my $date = Apache::Util::format_time($r->request_time, FMT, GMT, $r->pool);

my $if_modified_since = $r->headers_in->{'If-Modified-Since'};

my $status = 200;
my $body   = '<html><head></head><body>Test</body></html>';

if ($if_modified_since && APR::Date::parse_http($last_modified) 
    < APR::Date::parse_http($if_modified_since)) {

    $status = 304;
    $body   = '';
}

print <<HEADERS;
Status: $status
Date: $date
Server: Apache/2.0.47
Connection: close
Last-Modified: $last_modified
Content-Type: text/html; charset=iso-8859-1

HEADERS

print $body if length $body;
