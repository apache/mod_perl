use strict;
use warnings FATAL => 'all';

use Apache::Test;

use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 31, todo => [25, 28, 30], \&have_lwp;

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
    ok t_cmp(
        "@data",
        POST_BODY($location, \@data),
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

# Apache->gensym
{
    my @data = (test => 'gensym');
    my $data = GET_BODY query(@data) || '';
    ok_nok($data);
}

# header_in
t_header('in','get_scalar',q{scalar ctx: $r->header_in($key)});
t_header('in','get_list',  q{list ctx: $r->header_in($key)});
t_header('in','set',       q{$r->header_in($key => $val)});
t_header('in','unset',     q{$r->header_in($key => undef)});

# header_out
t_header('out','get_scalar',q{scalar ctx: $r->header_out($key)});
t_header('out','get_list',  q{list ctx: $r->header_out($key)});
t_header('out','set',       q{$r->header_out($key => $val)});
t_header('out','unset',     q{$r->header_out($key => undef)});

# Apache::File
{
    my @data = (test => 'Apache::File');
    my $data = GET_BODY query(@data) || '';
    ok_nok($data);
}


### helper subs ###
sub query {
    my(%args) = (@_ % 2) ? %{+shift} : @_;
    "$location?" . join '&', map { "$_=$args{$_}" } keys %args;
}

sub t_header {
    my ($way, $what, $comment) = @_;
    ok t_cmp(
        "ok",
        GET_BODY(query(test => 'header', way => $way, what => $what)),
        $comment
        );
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
