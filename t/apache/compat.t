use strict;
use warnings FATAL => 'all';

use Apache::Test;

use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 3;

my $location = "/TestApache::compat";

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


### helper subs ###
sub query {
    my(%args) = (@_ % 2) ? %{+shift} : @_;
    "$location?" . join '&', map { "$_=$args{$_}" } keys %args;
}

# accepts multiline var where, the lines matching:
# ^ok\n$  results in ok(1)
# ^nok\n$ results in ok(0)
# the rest is printed as is
sub ok_nok {
    for (split /\n/, shift) {
        if (/^ok\n?$/) {
            ok 1;
        } elsif (/^nok\n?$/) {
            ok 0;
        } else {
            print "$_\n";
        }
    }
}
