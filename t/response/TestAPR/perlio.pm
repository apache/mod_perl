package TestAPR::perlio;

use strict;
use warnings;# FATAL => 'all';

use Apache::Const -compile => 'OK';

use Apache::Test;
use Apache::TestUtil;

use APR::PerlIO ();

use Fcntl ();
use File::Spec::Functions qw(catfile);

sub handler {
    my $r = shift;

    plan $r, tests => 9, todo => [5], have_perl 'iolayers';

    my $vars = Apache::Test::config()->{vars};
    my $dir  = catfile $vars->{documentroot}, "perlio";

    t_mkdir($dir);

    # write file
    my $file = catfile $dir, "test";
    t_debug "open file $file";
    my $foo = "bar";
    open my $fh, ">:APR", $file, $r
        or die "Cannot open $file for writing: $!";
    ok ref($fh) eq 'GLOB';

    my $expected = "This is a test: $$";
    t_debug "write to a file: $expected";
    print $fh $expected;
    close $fh;

    # open() other tests
    {
        # non-existant file
        my $file = "/this/file/does/not/exist";
        t_write_file("/tmp/testing", "some stuff");
        if (open my $fh, "<:APR", $file, $r) {
            t_debug "must not be able to open $file!";
            ok 0;
            close $fh;
        }
        else {
            t_debug "good! cannot open/doesn't exist: $!";
            ok 1;
        }
    }

    # read() test
    {
        open my $fh, "<:APR", $file, $r
            or die "Cannot open $file for reading: $!";
        ok ref($fh) eq 'GLOB';

        my $received = <$fh>;
        close $fh;

        ok t_cmp($expected,
                 $received,
                 "read/write file");
    }

    # seek/tell() tests
    {
        open my $fh, "<:APR", $file, $r 
            or die "Cannot open $file for reading: $!";

        my $pos = 3;
        seek $fh, $pos, Fcntl::SEEK_SET();
        # XXX: broken
        my $got = tell($fh);
        ok t_cmp($pos,
                 $got,
                 "seek/tell the file");

        # XXX: test Fcntl::SEEK_CUR() Fcntl::SEEK_END()
        close $fh;

    }

    # eof() tests
    {
        open my $fh, "<:APR", $file, $r 
            or die "Cannot open $file for reading: $!";

        ok t_cmp(0,
                 int eof($fh), # returns false, not 0
                 "not end of file");
        # go to the end and read
        seek $fh, 0, Fcntl::SEEK_END();
        my $received = <$fh>;

        ok t_cmp(1,
                 eof($fh),
                 "end of file");
        close $fh;
    }

    # dup() test
    {
        open my $fh, "<:APR", $file, $r 
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

    # XXX: need tests 
    # - for stdin/out/err as they are handled specially
    # - unbuffered read $|=1?

    # XXX: tmpfile is missing:
    # consider to use 5.8's syntax: 
    #   open $fh, "+>", undef;

    # cleanup: t_mkdir will remove the whole tree including the file

    Apache::OK;
}

1;
