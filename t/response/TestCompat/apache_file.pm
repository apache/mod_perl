package TestCompat::apache_file;

# Apache::File compat layer tests

# these tests are all run and validated on the server side.

use strict;
use warnings FATAL => 'all';

use Apache::TestUtil;
use Apache::Test;

use Apache::compat ();
use Apache::Constants qw(OK);

sub handler {
    my $r = shift;

    plan $r, tests => 18;

    $r->send_http_header('text/plain');

    my $cfg = Apache::Test::config();
    my $vars = $cfg->{vars};

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
    ok t_cmp($write, <$tmpfh>, "write/read from tmpfile");

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

#    #$r->set_content_length();
#    #TODO
#    ok t_cmp(0, # XXX: $r->finfo->csize is not available yet
#        $r->headers_out->{"Content-length"},
#        "\$r->set_content_length() w/o setting explicit size");


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

    OK;
}

1;

__END__
PerlOptions +GlobalRequest
