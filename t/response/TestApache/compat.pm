package TestApache::compat;

use strict;
use warnings FATAL => 'all';

use Apache::compat ();

use Apache::TestUtil;
use Apache::Constants qw(OK M_POST DECLINED);

sub handler {
    my $r = shift;

    $r->send_http_header('text/plain');

    my %data;
    if ($r->method_number == M_POST) {
        %data = $r->content;
    }
    else {
        %data = $r->Apache::args;
    }

    return DECLINED unless exists $data{test};

    if ($data{test} eq 'content' || $data{test} eq 'args') {
        $r->print("test $data{test}");
    }
    elsif ($data{test} eq 'header') {
        my $way      = $data{way};
        my $sub      = "header_$way";
        my $sub_good = "headers_$way";
        if ($data{what} eq 'get_scalar') {
            # get in scalar ctx
            my $key;
            if ($way eq 'in') {
                $key = "user-agent"; # should exist with lwp
            }
            else {
                # outgoing headers aren't set yet, so we set one
                $key = "X-barabara";
                $r->$sub_good->set($key, $key x 2);
            }
            my $exp = $r->$sub_good->get($key);
            my $got = $r->$sub($key);
            $r->print(t_is_equal($exp, $got) ? 'ok' : 'nok');
        }
        elsif ($data{what} eq 'get_list') {
            # get in list ctx
            my $key = $data{test};
            my @exp = qw(foo bar);
            $r->$sub_good->add($key => $_) for @exp;
            my @got = $r->$sub($key);
            $r->print(t_is_equal(\@exp, \@got) ? 'ok' : 'nok');
        }
        elsif ($data{what} eq 'set') {
            # set
            my $key = $data{test};
            my $exp = $key x 2;
            $r->$sub($key => $exp);
            my $got = $r->$sub($key);
            $r->print(t_is_equal($exp, $got) ? 'ok' : 'nok');
        }
        elsif ($data{what} eq 'unset') {
            # unset
            my $key = $data{test};
            my $exp = undef;
            $r->$sub($key => $exp);
            my $got = $r->$sub($key);
            $r->print(t_is_equal($exp, $got) ? 'ok' : 'nok');
        }
    }

    OK;
}

1;
