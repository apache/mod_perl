package TestAPI::uri;

use strict;
use warnings FATAL => 'all';

use Apache::URI ();
use Apache::RequestUtil ();
use Apache::Test;

my $location = '/' . __PACKAGE__;

sub handler {
    my $r = shift;

    plan $r, tests => 14;

    $r->args('query');

    my $uri = $r->parsed_uri;

    ok $uri->isa('Apache::URI');

    ok $uri->path =~ m:^$location:;

    my $up = $uri->unparse;
    ok $up =~ m:^$location:;

    my $parsed = Apache::URI->parse($r);

    ok $parsed->isa('Apache::URI');

    $up = $parsed->unparse;

    ok $up =~ m:$location:;

    ok $parsed->query eq $r->args;

    my $path = '/foo/bar';

    $parsed->path($path);

    ok $parsed->path eq $path;

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
