package TestAPR::perlio;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Fcntl ();
use File::Spec::Functions qw(catfile);

use Apache::Const -compile => 'OK';

#XXX: APR::LARGE_FILES_CONFLICT constant?
#XXX: you can set to zero if largefile support is not enabled in Perl
use constant LARGE_FILES_CONFLICT => 1;

sub handler {
    my $r = shift;

    my $tests = 12;
    my $lfs_tests = 3;

    $tests += $lfs_tests unless LARGE_FILES_CONFLICT;

    # 1) APR::PerlIO is not available on all platforms
    # 2) on those platforms where available,
    #    PerlIO-enabled perl is needed to run this test
    my $run = eval { require APR::PerlIO } && 
        APR::PerlIO::PERLIO_LAYERS_ARE_ENABLED()
            ? 1
            : have  { "This Perl build doesn't support PerlIO layers" => 0 };

    plan $r, tests => $tests, $run;

    my $vars = Apache::Test::config()->{vars};
    my $dir  = catfile $vars->{documentroot}, "perlio";

    t_mkdir($dir);

    my $sep = "-- sep --\n";
    my @lines = ("This is a test: $$\n", "test line --sep two\n");

    my $expected = $lines[0];
    my $expected_all = join $sep, @lines;

    # write file
    my $file = catfile $dir, "test";
    t_debug "open file $file for writing";
    my $foo = "bar";
    open my $fh, ">:APR", $file, $r->pool
        or die "Cannot open $file for writing: $!";
    ok ref($fh) eq 'GLOB';

    t_debug "write to a file:\n$expected\n";
    print $fh $expected_all;
    close $fh;

    # open() failure test
    {
        # workaround for locale setups where the error message may be
        # in a different language
        open my $fh, "perlio_this_file_cannot_exist";
        my $errno_string = "$!";

        # non-existent file
        my $file = "/this/file/does/not/exist";
        if (open my $fh, "<:APR", $file, $r->pool) {
            t_debug "must not be able to open $file!";
            ok 0;
            close $fh;
        }
        else {
            ok t_cmp($errno_string,
                     "$!",
                     "expected failure");
        }
    }

    # seek/tell() tests
    unless (LARGE_FILES_CONFLICT) {
        open my $fh, "<:APR", $file, $r->pool
            or die "Cannot open $file for reading: $!";

        # read the whole file so we can test the buffer flushed
        # correctly on seek.
        my $dummy = join '', <$fh>;

        # Fcntl::SEEK_SET()
        my $pos = 3; # rewinds after reading 6 chars above
        seek $fh, $pos, Fcntl::SEEK_SET();
        my $got = tell($fh);
        ok t_cmp($pos,
                 $got,
                 "seek/tell the file Fcntl::SEEK_SET");

        # Fcntl::SEEK_CUR()
        my $step = 10;
        $pos = tell($fh) + $step;
        seek $fh, $step, Fcntl::SEEK_CUR();
        $got = tell($fh);
        ok t_cmp($pos,
                 $got,
                 "seek/tell the file Fcntl::SEEK_CUR");

        # Fcntl::SEEK_END()
        $pos = -s $file;
        seek $fh, 0, Fcntl::SEEK_END();
        $got = tell($fh);
        ok t_cmp($pos,
                 $got,
                 "seek/tell the file Fcntl::SEEK_END");

        close $fh;
    }

    # read() tests
    {
        open my $fh, "<:APR", $file, $r->pool
            or die "Cannot open $file for reading: $!";

        # basic open test
        ok ref($fh) eq 'GLOB';

        # basic single line read
        ok t_cmp($expected,
                 scalar(<$fh>),
                 "single line read");

        # slurp mode
        seek $fh, 0, Fcntl::SEEK_SET(); # rewind to the start
        local $/;

        ok t_cmp($expected_all,
                 scalar(<$fh>),
                 "slurp file");

        # test ungetc (a long sep requires read ahead)
        seek $fh, 0, Fcntl::SEEK_SET(); # rewind to the start
        local $/ = $sep;
        my @got_lines = <$fh>;
        my @expect = ($lines[0] . $sep, $lines[1]);
        ok t_cmp(\@expect,
                 \@got_lines,
                 "custom complex input record sep read");

        close $fh;
    }


    # eof() tests
    {
        open my $fh, "<:APR", $file, $r->pool
            or die "Cannot open $file for reading: $!";

        ok t_cmp(0,
                 int eof($fh), # returns false, not 0
                 "not end of file");
        # go to the end and read so eof will return 1
        seek $fh, 0, Fcntl::SEEK_END();
        my $received = <$fh>;

        t_debug($received);

        ok t_cmp(1,
                 eof($fh),
                 "end of file");
        close $fh;
    }

    # dup() test
    {
        open my $fh, "<:APR", $file, $r->pool
            or die "Cannot open $file for reading: $!";

        open my $dup_fh, "<&:APR", $fh
            or die "Cannot dup $file for reading: $!";
        close $fh;
        ok ref($dup_fh) eq 'GLOB';

        my $received = <$dup_fh>;

        close $dup_fh;
        ok t_cmp($expected,
                 $received,
                 "read/write a dupped file");
    }

    # unbuffered write
    {
        open my $wfh, ">:APR", $file, $r->pool
            or die "Cannot open $file for writing: $!";
        open my $rfh,  "<:APR", $file, $r->pool
            or die "Cannot open $file for reading: $!";

        my $expected = "This is an un buffering write test";
        # unbuffer
        my $oldfh = select($wfh); $| = 1; select($oldfh);
        print $wfh $expected; # must be flushed to disk immediately

        ok t_cmp($expected,
                 scalar(<$rfh>),
                 "file unbuffered write");

        # buffer up
        $oldfh = select($wfh); $| = 0; select($oldfh);
        print $wfh $expected; # should be buffered up and not flushed

        ok t_cmp(undef,
                 scalar(<$rfh>),
                 "file buffered write");

        close $wfh;
        close $rfh;

    }


    # XXX: need tests 
    # - for stdin/out/err as they are handled specially

    # XXX: tmpfile is missing:
    # consider to use 5.8's syntax: 
    #   open $fh, "+>", undef;

    # cleanup: t_mkdir will remove the whole tree including the file

    Apache::OK;
}

1;
