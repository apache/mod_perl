package TestAPI::uri;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use APR::URI ();
use Apache::URI ();
use Apache::RequestRec ();
use Apache::RequestUtil ();

use Apache::Const -compile => 'OK';

my $location = '/' . __PACKAGE__;

sub handler {
    my $r = shift;

    # since Apache::compat redefines APR::URI::unparse and the test for
    # backcompat Apache::URI forces redefinition of APR::URI::unparse
    # (to get the right behavior during the test),
    # we need to force reload of APR::URI
    delete $INC{"APR/URI.pm"};
    no warnings 'redefine';
    require APR::URI;

    plan $r, tests => 15;

    $r->args('query');

    my $uri = $r->parsed_uri;

    ok $uri->isa('APR::URI');

    ok $uri->path =~ m:^$location:;

    my $up = $uri->unparse;
    ok $up =~ m:^$location:;

    my $server = $r->construct_server;
    ok $server eq join ':', $r->get_server_name, $r->get_server_port;

    my $curl = $r->construct_url;
    my $parsed = APR::URI->parse($r->pool, $curl);

    ok $parsed->isa('APR::URI');

    $up = $parsed->unparse;

    ok $up =~ m:$location:;

    #ok $parsed->query eq $r->args; #XXX?

    my $path = '/foo/bar';

    $parsed->path($path);

    ok $parsed->path eq $path;

    {
        # test the segfault in apr < 0.9.2 (fixed on mod_perl side)
        # passing only the /path
        my $parsed = APR::URI->parse($r->pool, $r->uri);
        # set hostname, but not the scheme
        $parsed->hostname($r->get_server_name);
        $parsed->port($r->get_server_port);
        #$parsed->scheme('http');
        my $expected = $r->construct_url;
        my $received = $parsed->unparse;
        t_debug("the real received is: $received");
        # apr < 0.9.2-dev + fix in mpxs_apr_uri_unparse will return
        #    '://localhost.localdomain:8529/TestAPI::uri'
        # apr >= 0.9.2 with internal fix will return
        #    '//localhost.localdomain:8529/TestAPI::uri'
        # so in order to test pre-0.9.2 and post-0.9.2-dev we massage it
        $expected =~ s|^http:||;
        $received =~ s|^:||;
        ok t_cmp($expected, $received,
                 "the bogus url is expected when 'hostname' is set " .
                 "but not 'scheme'");
    }

    my $newr = Apache::RequestRec->new($r->connection, $r->pool);
    my $url_string = "$path?query";

    $newr->parse_uri($url_string);

    ok $newr->uri eq $path;

    ok $newr->args eq 'query';

    my $puri = $newr->parsed_uri;

    ok $puri->path eq $path;

    ok $puri->query eq 'query';

    my @c = qw(one two three);
    $url_string = join '%20', @c;

    Apache::unescape_url($url_string);

    ok $url_string eq "@c";

    my $port = 6767;
    $puri->port($port);
    $puri->scheme('ftp');
    $puri->hostname('perl.apache.org');

    ok $puri->port == $port;

    ok $puri->unparse eq "ftp://perl.apache.org:$port$path?query";

    Apache::OK;
}

1;
