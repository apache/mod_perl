package TestAPR::date;

# testing APR::Date API

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use APR::Date ();

use Apache::Const -compile => 'OK';

my @http_dates = (
    'Sun, 06 Nov 1994 08:49:37 GMT',  # RFC 822, updated by RFC 1123
    'Sunday, 06-Nov-94 08:49:37 GMT', # RFC 850, obsoleted by RFC 1036
    'Sun Nov  6 08:49:37 1994',       # ANSI C's asctime() format
);

my @rfc_dates = (
    'Sun, 06 Nov 1994 08:49:37 GMT' , # RFC 822, updated by RFC 1123
    'Sunday, 06-Nov-94 08:49:37 GMT', # RFC 850, obsoleted by RFC 1036
    'Sun Nov  6 08:49:37 1994',       # ANSI C's asctime() format
    'Sun, 6 Nov 1994 08:49:37 GMT',   # RFC 822, updated by RFC 1123
    'Sun, 06 Nov 94 08:49:37 GMT',    # RFC 822
    'Sun, 6 Nov 94 08:49:37 GMT',     # RFC 822
    'Sun, 06 Nov 94 8:49:37 GMT',     # Unknown [Elm 70.85]
    'Sun, 6 Nov 94 8:49:37 GMT',      # Unknown [Elm 70.85]
    'Sun,  6 Nov 1994 08:49:37 GMT',  # Unknown [Postfix]
);

my @bogus_dates = (
    'Sun, 06 Nov 94 08:49 GMT',       # Unknown [drtr@ast.cam.ac.uk]
    'Sun, 6 Nov 94 08:49 GMT',        # Unknown [drtr@ast.cam.ac.uk]
);

my $date_msec = 784111777;
my $bogus_date_msec = 784111740;

sub handler {
    my $r = shift;

    plan $r, tests => @http_dates + @rfc_dates + @bogus_dates;

    # parse_http
    for my $date_str (@http_dates) {
        ok t_cmp(APR::Date::parse_http($date_str),
                 $date_msec, 
                 "parse_http: $date_str");
        #t_debug "testing : parse_http: $date_str";
    }

    # parse_rfc
    for my $date_str (@rfc_dates) {
        ok t_cmp(APR::Date::parse_rfc($date_str),
                 $date_msec, 
                 "parse_rfc: $date_str");
        #t_debug "testing : parse_rfc: $date_str";
    }

    # parse_rfc (bogus formats)
    for my $date_str (@bogus_dates) {
        ok t_cmp(APR::Date::parse_rfc($date_str),
                 $bogus_date_msec,
                 "parse_rfc: $date_str");
        #t_debug "testing : parse_rfc: $date_str";
    }

    Apache::OK;
}

1;
__END__
