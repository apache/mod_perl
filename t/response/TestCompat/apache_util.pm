package TestCompat::apache_util;

# Apache::Util compat layer tests

# these tests are all run and validated on the server side.

use strict;
use warnings FATAL => 'all';

use Apache::TestUtil;
use Apache::Test;

use Apache::compat ();
use Apache::Constants qw(OK);

my %string_size = (
    '-1'            => "    -",
    0               => "   0k",
    42              => "   1k",
    42_000          => "  41k",
    42_000_000      => "40.1M",
    42_000_000_000  => "40054M",
);

sub handler {
    my $r = shift;

    plan $r, tests => 13;

    $r->send_http_header('text/plain');

    # size_string()
    {
        while (my($k, $v) = each %string_size) {
            ok t_cmp($v, Apache::Util::size_string($k));
        }
    }

    # escape_uri(), escape_path(), unescape_uri()
    my $uri = "http://foo.com/a file.html";
    (my $esc_uri = $uri) =~ s/ /\%20/g;
    my $uri2 = $uri;

    $uri = Apache::Util::escape_uri($uri);
    $uri2 = Apache::Util::escape_path($uri2, $r->pool);

    ok t_cmp($esc_uri, $uri, "Apache::Util::escape_uri");
    ok t_cmp($esc_uri, $uri2, "Apache::Util::escape_path");

    ok t_cmp(Apache::unescape_url($uri),
             Apache::Util::unescape_uri($uri2),
             "Apache::URI::unescape_uri vs Apache::Util::unescape_uri");

    ok t_cmp($uri,
             $uri2,
             "Apache::URI::unescape_uri vs Apache::Util::unescape_uri");

    # escape_html()
    my $html = '<p>"hi"&foo</p>';
    my $esc_html = '&lt;p&gt;&quot;hi&quot;&amp;foo&lt;/p&gt;';

    ok t_cmp($esc_html, Apache::Util::escape_html($html),
             "Apache::Util::escape_html");


    # ht_time(), parsedate()
    my $time = time;
    my $fmtdate = Apache::Util::ht_time($time);

    ok t_cmp($fmtdate, $fmtdate, "Apache::Util::ht_time");

    my $ptime = Apache::Util::parsedate($fmtdate);

    ok t_cmp($time, $ptime, "Apache::Util::parsedate");

    # note these are not actually part of the tests since i think on
    # platforms where crypt is not supported, these tests will fail.
    # but at least we can look with t/TEST -v
    my $hash = "aX9eP53k4DGfU";
    t_cmp(1, Apache::Util::validate_password("dougm", $hash));
    t_cmp(0, Apache::Util::validate_password("mguod", $hash));


    OK;
}

1;

__END__
PerlOptions +GlobalRequest
