use strict;
use warnings FATAL => 'all';

use Apache::Test;

use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 5;

my $location = "/TestCompat::request_body";

# $r->send_http_header('text/plain');
{
    my @data = (test => 'content-type');
    ok t_cmp(
        "text/plain",
        HEAD(query(@data))->content_type(),
        q{$r->send_http_header('text/plain')}
        );
}

# $r->content
{
    my @data = (test => 'content');
    my $content = join '=', @data;
    ok t_cmp(
        "@data",
        POST_BODY($location, content => $content),
        q{$r->content via POST}
        );
}

# $r->Apache::args
{
    my @data = (test => 'args');
    ok t_cmp(
        "@data",
        GET_BODY(query(@data)),
        q{$r->Apache::args}
        );
}

# encoding/decoding
{
    my %data = (
        test => 'decoding',
        body => '%DC%DC+%EC%2E+%D6%D6+%D6%2F',
    );
    ok t_cmp(
        $data{body},
        GET_BODY(query(%data)),
        q{decoding}
       );
}


# big POST
{
    my %data = (
        test => 'big_input',
        body => ('x' x 819_235),
       );
    my $content = join '=', %data;
    ok t_cmp(
        length($data{body}),
        POST_BODY($location, content => $content),
        q{big POST}
       );
}



### helper subs ###
sub query {
    my(%args) = (@_ % 2) ? %{+shift} : @_;
    "$location?" . join '&', map { "$_=$args{$_}" } keys %args;
}

