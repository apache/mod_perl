package TestApache::compat;

use strict;
use warnings FATAL => 'all';

use Apache::TestUtil;
use Apache::Test ();

use Apache::compat ();
use Apache::Constants qw(OK M_POST DECLINED);

use subs qw(ok debug);
my $gr;

sub handler {
    my $r = shift;
    $gr = $r;

    $r->send_http_header('text/plain');

    my $cfg = Apache::Test::config();
    my $vars = $cfg->{vars};

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
    elsif ($data{test} eq 'gensym') {
        debug "Apache->gensym";
        my $fh = Apache->gensym;
        ok ref $fh eq 'GLOB';
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
    elsif ($data{test} eq 'Apache::File') {
        require Apache::File;
        my $file = $vars->{t_conf_file};

        debug "new Apache::File file object";
        ok my $fh = Apache::File->new;

        debug "open itself";
        if ($fh->open($file)) {
            ok 1;
            debug "read from file";
            my $read = <$fh>;
            ok $read;
            debug "close file";
            ok $fh->close;
        }
        else {
            debug "open $file failed: $!";
            ok 0;
            debug "ok: cannot read from the closed fh";
            ok 1;
            debug "ok: close file should fail, wasn't opened";
            ok !$fh->close;
        }

        debug "open non-exists";
        ok !$fh->open("$file.nochance");

        debug "new+open";
        if (my $fh = Apache::File->new($file)) {
            ok 1;
            $fh->close;
        }
        else {
            ok 0;
        }

        debug "new+open non-exists";
        ok !Apache::File->new("$file.yeahright");

        # tmpfile
        my ($tmpfile, $tmpfh) = Apache::File->tmpfile;

        debug "open tmpfile fh";
        ok $tmpfh;

        debug "open tmpfile name";
        ok $tmpfile;

        debug "write/read from tmpfile";
        my $write = "test $$";
        print $tmpfh $write;
        seek $tmpfh, 0, 0;
        my $read = <$tmpfh>;
        ok $read eq $write;

        debug "\$r->discard_request_body";
        ok $r->discard_request_body == Apache::OK;

        debug "\$r->meets_conditions";
        ok $r->meets_conditions == Apache::OK;

        debug "\$r->set_content_length";
        # XXX: broken
        #$r->set_content_length();
        ok 0;
        $r->set_content_length(10);
        my $cl_header = $r->headers_out->{"Content-length"} || '';
        ok $cl_header == 10;

        # XXX: how to test etag?
        debug "\$r->set_etag";
        $r->set_etag;
        ok 1;

        debug "\$r->update_mtime/\$r->mtime";
        # XXX: broken
        # $r->update_mtime; # just check that it's valid
        ok 0;
        my $time = time;
        $r->update_mtime($time);
        ok $r->mtime == $time;

        debug "\$r->set_last_modified";
        # XXX: broken
        # $r->set_last_modified($time);
        ok 0;
        $time = time;
        $r->set_last_modified();
        ok $r->mtime == $time;
    }

    Apache::OK;
}

sub ok    { $gr->print($_[0] ? "ok\n" : "nok\n"); }
sub debug { $gr->print("# $_\n") for @_; }

1;
__END__
PerlOptions +GlobalRequest
