package TestAPI::uri;

use strict;
use warnings FATAL => 'all';

use Apache::URI ();
use Apache::RequestUtil ();
use Apache::Test;

my $location = '/' . __PACKAGE__;

sub handler {
    my $r = shift;

    plan $r, tests => 12;

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

    my $newr = Apache::RequestRec->new($r->connection);
    my $url_string = "$path?query";

    $newr->parse_uri($url_string);

    ok $newr->uri eq $path;

    ok $newr->args eq 'query';

    ok $newr->parsed_uri->path eq $path;

    ok $newr->parsed_uri->query eq 'query';

    my @c = qw(one two three);
    $url_string = join '%20', @c;

    Apache::unescape_url($url_string);

    ok $url_string eq "@c";

    Apache::OK;
}

1;
