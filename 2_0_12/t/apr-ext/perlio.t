#!perl -T
# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-

use strict;
use warnings FATAL => 'all';

# XXX: this is pretty much the same test as
# t/response/TestAPR/perlio.pm, but used outside mod_perl
# consider avoiding the code duplication.

use Apache::Test;
use Apache::TestUtil;
use Apache2::Build ();

use Fcntl ();
use File::Spec::Functions qw(catfile);

#XXX: APR::LARGE_FILES_CONFLICT constant?
#XXX: you can set to zero if largefile support is not enabled in Perl
use constant LARGE_FILES_CONFLICT => 1;

my $build = Apache2::Build->build_config;

# XXX: only when apr-config is found APR will be linked against
# libapr/libaprutil, probably need a more intuitive method for this
# prerequisite
# also need to check whether we build against the source tree, in
# which case we APR.so won't be linked against libapr/libaprutil
my $has_apr_config = $build->{apr_config_path} &&
    !$build->httpd_is_source_tree;

my $has_perlio_layers = 0;
if ($has_apr_config) {
    require APR;
    require APR::PerlIO;
    $has_perlio_layers = 1 if APR::PerlIO::PERLIO_LAYERS_ARE_ENABLED();
}

my $tests = 12;
my $lfs_tests = 3;

$tests += $lfs_tests unless LARGE_FILES_CONFLICT;
require APR; require APR::PerlIO;
plan tests => $tests,
    need {"this build couldn't find apr-config"      => $has_apr_config,
          "this build doesn't support PerlIO layers" => $has_perlio_layers,
    };

require APR::Pool;

my $pool = APR::Pool->new();

my $vars = Apache::Test::config()->{vars};
my $dir  = catfile $vars->{documentroot}, "perlio-ext";

t_mkdir($dir);

my $sep = "-- sep --\n";
my @lines = ("This is a test: $$\n", "test line --sep two\n");

my $expected = $lines[0];
my $expected_all = join $sep, @lines;

# write file
my $file = catfile $dir, "test";
t_debug "open file $file for writing";
my $foo = "bar";
open my $fh, ">:APR", $file, $pool
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
    if (open my $fh, "<:APR", $file, $pool) {
        t_debug "must not be able to open $file!";
        ok 0;
        close $fh;
    } else {
        ok t_cmp("$!",
                 $errno_string,
                 "expected failure");
    }
}

# seek/tell() tests
unless (LARGE_FILES_CONFLICT) {
    open my $fh, "<:APR", $file, $pool
        or die "Cannot open $file for reading: $!";

    # read the whole file so we can test the buffer flushed
    # correctly on seek.
    my $dummy = join '', <$fh>;

    # Fcntl::SEEK_SET()
    my $pos = 3; # rewinds after reading 6 chars above
    seek $fh, $pos, Fcntl::SEEK_SET();
    my $got = tell($fh);
    ok t_cmp($got,
             $pos,
             "seek/tell the file Fcntl::SEEK_SET");

    # Fcntl::SEEK_CUR()
    my $step = 10;
    $pos = tell($fh) + $step;
    seek $fh, $step, Fcntl::SEEK_CUR();
    $got = tell($fh);
    ok t_cmp($got,
             $pos,
             "seek/tell the file Fcntl::SEEK_CUR");

    # Fcntl::SEEK_END()
    $pos = -s $file;
    seek $fh, 0, Fcntl::SEEK_END();
    $got = tell($fh);
    ok t_cmp($got,
             $pos,
             "seek/tell the file Fcntl::SEEK_END");

    close $fh;
}

# read() tests
{
    open my $fh, "<:APR", $file, $pool
        or die "Cannot open $file for reading: $!";

    # basic open test
    ok ref($fh) eq 'GLOB';

    # basic single line read
    ok t_cmp(scalar(<$fh>),
             $expected,
             "single line read");

    # slurp mode
    seek $fh, 0, Fcntl::SEEK_SET(); # rewind to the start
    local $/;
    ok t_cmp(scalar(<$fh>),
             $expected_all,
             "slurp file");

    # test ungetc (a long sep requires read ahead)
    seek $fh, 0, Fcntl::SEEK_SET(); # rewind to the start
    local $/ = $sep;
    my @got_lines = <$fh>;
    my @expect = ($lines[0] . $sep, $lines[1]);
    ok t_cmp(\@got_lines,
             \@expect,
             "custom complex input record sep read");

    close $fh;
}


# eof() tests
{
    open my $fh, "<:APR", $file, $pool
        or die "Cannot open $file for reading: $!";

    ok t_cmp(0,
             int eof($fh), # returns false, not 0
             "not end of file");
    # go to the end and read so eof will return 1
    seek $fh, 0, Fcntl::SEEK_END();
    my $received = <$fh>;

    t_debug($received);

    ok t_cmp(eof($fh),
             1,
             "end of file");
    close $fh;
}

# dup() test
{
    open my $fh, "<:APR", $file, $pool
        or die "Cannot open $file for reading: $!";

    open my $dup_fh, "<&:APR", $fh
        or die "Cannot dup $file for reading: $!";
    close $fh;
    ok ref($dup_fh) eq 'GLOB';

    my $received = <$dup_fh>;

    close $dup_fh;
    ok t_cmp($received,
             $expected,
             "read/write a dupped file");
}

# unbuffered write
{
    open my $wfh, ">:APR", $file, $pool
        or die "Cannot open $file for writing: $!";
    open my $rfh,  "<:APR", $file, $pool
        or die "Cannot open $file for reading: $!";

    my $expected = "This is an un buffering write test";
    # unbuffer
    my $oldfh = select($wfh); $| = 1; select($oldfh);
    print $wfh $expected; # must be flushed to disk immediately

    ok t_cmp(scalar(<$rfh>),
             $expected,
             "file unbuffered write");

    # buffer up
    $oldfh = select($wfh); $| = 0; select($oldfh);
    print $wfh $expected; # should be buffered up and not flushed

    ok t_cmp(scalar(<$rfh>),
             undef,
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

