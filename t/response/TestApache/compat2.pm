package TestApache::compat2;

# these Apache::compat tests are all run and validated on the server
# side. See also TestApache::compat.

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

    plan $r, tests => 45;

    $r->send_http_header('text/plain');

    my $cfg = Apache::Test::config();
    my $vars = $cfg->{vars};

    my $fh = Apache->gensym;
    ok t_cmp('GLOB', ref($fh), "Apache->gensym");

    # test header_in and header_out
    # and err_header_out
    for my $prefix ('err_', '') {
        my @ways = 'out';
        push @ways, 'in' unless $prefix;
        for my $way (@ways) {
            my $sub_test = "${prefix}header_$way";
            my $sub_good = "${prefix}headers_$way";
            my $key = 'header-test';

            # scalar context
            {
                my $key;
                if ($way eq 'in') {
                    $key = "user-agent"; # should exist with lwp
                } else {
                    # outgoing headers aren't set yet, so we set one
                    $key = "X-barabara";
                    $r->$sub_good->set($key, $key x 2);
                }

                ok t_cmp($r->$sub_good->get($key),
                         $r->$sub_test($key),
                         "\$r->$sub_test in scalar context");
            }

            # list context
            {
                my @exp = qw(foo bar);
                $r->$sub_good->add($key => $_) for @exp;
                ok t_cmp(\@exp,
                         [ $r->$sub_test($key) ],
                         "\$r->$sub_test in list context");
            }

            # set
            {
                my $exp = $key x 2;
                $r->$sub_test($key => $exp);
                my $got = $r->$sub_test($key);
                ok t_cmp($exp, $got, "\$r->$sub_test set()");
            }

            # unset
            {
                my $exp = undef;
                $r->$sub_test($key => $exp);
                my $got = $r->$sub_test($key);
                ok t_cmp($exp, $got, "\$r->$sub_test unset()");
            }
        }
    }

    # Apache::File
    {
        require Apache::File;
        my $file = $vars->{t_conf_file};

        t_debug "new Apache::File file object";
        ok my $fh = Apache::File->new;

        t_debug "open itself";
        if ($fh->open($file)) {
            ok 1;
            t_debug "read from file";
            my $read = <$fh>;
            ok $read;
            t_debug "close file";
            ok $fh->close;
        }
        else {
            t_debug "open $file failed: $!";
            ok 0;
            t_debug "ok: cannot read from the closed fh";
            ok 1;
            t_debug "ok: close file should fail, wasn't opened";
            ok !$fh->close;
        }

        t_debug "open non-exists";
        ok !$fh->open("$file.nochance");

        t_debug "new+open";
        if (my $fh = Apache::File->new($file)) {
            ok 1;
            $fh->close;
        }
        else {
            ok 0;
        }

        t_debug "new+open non-exists";
        ok !Apache::File->new("$file.yeahright");

        # tmpfile
        my ($tmpfile, $tmpfh) = Apache::File->tmpfile;

        t_debug "open tmpfile fh";
        ok $tmpfh;

        t_debug "open tmpfile name";
        ok $tmpfile;

        my $write = "test $$";
        print $tmpfh $write;
        seek $tmpfh, 0, 0;
        ok t_cmp($write, scalar(<$tmpfh>), "write/read from tmpfile");

        ok t_cmp(Apache::OK,
                 $r->discard_request_body,
                 "\$r->discard_request_body");

        ok t_cmp(Apache::OK,
                 $r->meets_conditions,
                 "\$r->meets_conditions");

        my $csize = 10;
        $r->set_content_length($csize);
        ok t_cmp($csize,
                 $r->headers_out->{"Content-length"},
                 "\$r->set_content_length($csize) w/ setting explicit size");

#        $r->set_content_length();
        # TODO
#        ok t_cmp(0, # XXX: $r->finfo->csize is not available yet
#                 $r->headers_out->{"Content-length"},
#                 "\$r->set_content_length() w/o setting explicit size");

        # XXX: how to test etag?
        t_debug "\$r->set_etag";
        $r->set_etag;
        ok 1;

        # $r->update_mtime
        t_debug "\$r->update_mtime()";
        $r->update_mtime; # just check that it's valid
        ok 1;

        my $time = time;
        $r->update_mtime($time);
        ok t_cmp($time, $r->mtime, "\$r->update_mtime(\$time)/\$r->mtime");

        # $r->set_last_modified
        $r->set_last_modified();
        ok t_cmp($time, $r->mtime, "\$r->set_last_modified()");

        $r->set_last_modified($time);
        ok t_cmp($time, $r->mtime, "\$r->set_last_modified(\$time)");

    }

    # Apache::Util::size_string
    {
        while (my($k, $v) = each %string_size) {
            ok t_cmp($v, Apache::Util::size_string($k));
        }
    }

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

    my $html = '<p>"hi"&foo</p>';
    my $esc_html = '&lt;p&gt;&quot;hi&quot;&amp;foo&lt;/p&gt;';

    ok t_cmp($esc_html, Apache::Util::escape_html($html),
             "Apache::Util::escape_html");


    my $time = time;
    my $fmtdate = Apache::Util::ht_time($time);

    ok t_cmp($fmtdate, $fmtdate, "Apache::Util::ht_time");

    my $ptime = Apache::Util::parsedate($fmtdate);

    ok t_cmp($time, $ptime, "Apache::Util::parsedate");

    my $t = Apache::Table->new($r);
    my $t_class = ref $t;

    ok t_cmp('APR::Table', $t_class, "Apache::Table->new");

    #note these are not actually part of the tests
    #since i think on platforms where crypt is not supported,
    #these tests will fail.  but at least we can look with t/TEST -v
    my $hash = "aX9eP53k4DGfU";
    t_cmp(1, Apache::Util::validate_password("dougm", $hash));
    t_cmp(0, Apache::Util::validate_password("mguod", $hash));

    $r->post_connection(sub { OK });

    OK;
}


1;
__END__
PerlOptions +GlobalRequest
