package TestAPR::uri;

# Testing APR::URI (more tests in TestAPI::uri)

# XXX: this test could use more sub-tests to test various flags to
# unparse,

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use APR::URI ();

use Apache::Const -compile => 'OK';
use APR::Const    -compile => qw(URI_UNP_REVEALPASSWORD);

my %default_ports = (
    ftp      => 21,
    gopher   => 70,
    http     => 80,
    https    => 443,
    nntp     => 119,
    prospero => 191,
    snews    => 563,
    wais     => 210,
);

my %url = (
    scheme   => ["http",            "ftp"            ],
    user     => ["user",            "log"            ],
    password => ["password",        "pass"           ],
    hostname => ["www.example.com", "ftp.example.com"],
    port     => [8000,               21              ],
    path     => ["/path/file.pl",   "/pub"           ],
    query    => ["query",           undef            ],
    fragment => ["fragment",        undef            ],
);

my @keys_urls = qw(scheme user password hostname port path query
                   fragment);
my @keys_hostinfo = qw(user password hostname port);

sub handler {
    my $r = shift;

    plan $r, tests => 22;

    ### parse ###
    my $url0 = sprintf "%s://%s:%s\@%s:%d%s?%s#%s",
        map { $url{$_}[0] } @keys_urls;
    # warn "URL: $url\n";
    my $hostinfo0 =  sprintf "%s:%s\@%s:%d",
        map { $url{$_}[0] } @keys_hostinfo;

    my $parsed = APR::URI->parse($r->pool, $url0);
    ok $parsed;
    ok $parsed->isa('APR::URI');

    for my $method (keys %url) {
        no strict 'refs';
        ok t_cmp($url{$method}[0], $parsed->$method, $method);
    }

    ok t_cmp($hostinfo0, $parsed->hostinfo, "hostinfo");

    for my $method (keys %url) {
        no strict 'refs';
        $parsed->$method($url{$method}[1]);
        t_debug("$method: " . ($url{$method}[1]||'undef') .
                " => " . ($parsed->$method||'undef'));
    }

    ### unparse ###
    my $url_unparsed = $parsed->unparse;

    # hostinfo is unaffected, since it's simply a field in the parsed
    # record, and it's populated when parse is called, but when
    # individual fields used to compose it are updated, it doesn't get
    # updated: so we see the old value here
    ok t_cmp($hostinfo0, $parsed->hostinfo, "hostinfo");

    # - since 21 is the default port for ftp, unparse omits it
    # - if no flags are passed to unparse, APR::URI_UNP_OMITPASSWORD
    #   is passed by default -- it hides the password
    my $url1 = sprintf "%s://%s\@%s%s",
        map { $url{$_}[1] } grep !/^(password|port)$/, @keys_urls;
    ok t_cmp($url1, $url_unparsed, "unparsed url");

    # this time the password should appear
    {
        my $url_unparsed = $parsed->unparse(APR::URI_UNP_REVEALPASSWORD);
        my $url2 = sprintf "%s://%s:%s\@%s%s",
            map { $url{$_}[1] } grep !/^port$/, @keys_urls;
        ok t_cmp($url2, $url_unparsed, "unparsed url");
    }

    ### port_of_scheme ###
    while (my($scheme, $port) = each %default_ports) {
        my $apr_port = APR::URI::port_of_scheme($scheme);
        ok t_cmp($port, $apr_port, "scheme: $scheme");
    }

    Apache::OK;
}



1;
