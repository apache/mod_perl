use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;
use File::Spec::Functions;

# this test tests how various registry packages cache and flush the
# scripts their run, and whether they check modification on the disk
# or not. We don't test the closure side effect, but we use it as a
# test aid. The tests makes sure that they run through the same
# interpreter all the time (in case that the server is running more
# than one interpreter)

my @modules = qw(registry registry_bb perlrun);

plan tests => 6;

my $cfg = Apache::Test::config();

my $file = 'closure.pl';
my $path = catfile $cfg->{vars}->{serverroot}, 'cgi-bin', $file;

# for all sub-tests in this test, we make sure that we always get onto
# the same interpreter. if this doesn't happen we skip the sub-test or
# a group of them, where several sub-tests rely on each other.

{
    # ModPerl::PerlRun
    # always flush
    # no cache

    my $url = "/same_interp/perlrun/$file";
    my $same_interp = Apache::TestRequest::same_interp_tie($url);

    # should be no closure effect, always returns 1
    my $first  = get_body($same_interp, $url);
    my $second = get_body($same_interp, $url);
    skip_not_same_intrep(
        (scalar(grep defined, $first, $second) != 2),
        0,
        $first && $second && ($second - $first),
        "never the closure problem",
    );

    # modify the file
    sleep_and_touch_file($path);

    # it doesn't matter, since the script is not cached anyway
    my $third = get_body($same_interp, $url);
    skip_not_same_intrep(
        (scalar(grep defined, $first, $second, $third) != 3),
        1,
        $third,
        "never the closure problem",
    );
}

{
    # ModPerl::Registry
    # no flush
    # cache, but reload on modification
    my $url = "/same_interp/registry/$file";
    my $same_interp = Apache::TestRequest::same_interp_tie($url);

    # we don't know what other test has called this uri before, so we
    # check the difference between two subsequent calls. In this case
    # the difference should be 1.
    my $first  = get_body($same_interp, $url);
    my $second = get_body($same_interp, $url);
    skip_not_same_intrep(
        (scalar(grep defined, $first, $second) != 2),
        1,
        $first && $second && ($second - $first),
        "the closure problem should exist",
    );

    # modify the file
    sleep_and_touch_file($path);

    # should not notice closure effect on the first request
    my $third = get_body($same_interp, $url);
    skip_not_same_intrep(
        (scalar(grep defined, $first, $second, $third) != 3),
        1,
        $third,
        "no closure on the first request",
    );
}

{
    # ModPerl::RegistryBB
    # no flush
    # cache once, don't check for mods
    my $url = "/same_interp/registry_bb/$file";
    my $same_interp = Apache::TestRequest::same_interp_tie($url);

    # we don't know what other test has called this uri before, so we
    # check the difference between two subsequent calls. In this case
    # the difference should be 1.
    my $first  = get_body($same_interp, $url);
    my $second = get_body($same_interp, $url);
    skip_not_same_intrep(
        (scalar(grep defined, $first, $second) != 2),
        1,
        $first && $second && ($second - $first),
        "the closure problem should exist",
    );

    # modify the file
    sleep_and_touch_file($path);

    # modification shouldn't be noticed
    my $third = get_body($same_interp, $url);
    skip_not_same_intrep(
        (scalar(grep defined, $first, $second, $third) != 3),
        1,
        $first && $second && $third - $second,
        "no reload on modification, the closure problem persists",
    );
}

sub sleep_and_touch_file {
    my $file = shift;
    # need to wait at least 1 whole sec, so utime() will notice the
    # difference. select() has better resolution than 1 sec as in
    # sleep() so we are more likely to have the minimal waiting time,
    # while fulfilling the purpose
    select undef, undef, undef, 1.00; # sure 1 sec
    my $now = time;
    utime $now, $now, $file;
}

# if we fail to find the same interpreter, return undef (this is not
# an error)
sub get_body {
    my($same_interp, $url) = @_;
    my $res = eval {
        Apache::TestRequest::same_interp_do($same_interp, \&GET, $url);
    };
    return undef if $@ =~ /unable to find interp/;
    return $res->content if $res;
    die $@ if $@;
}


# make the tests resistant to a failure of finding the same perl
# interpreter, which happens randomly and not an error.
# the first argument is used to decide whether to skip the sub-test,
# the rest of the arguments are passed to 'ok t_cmp';
sub skip_not_same_intrep {
    my $skip_cond = shift;
    if ($skip_cond) {
        skip "Skip couldn't find the same interpreter";
    }
    else {
        my($package, $filename, $line) = caller;
        # trick ok() into reporting the caller filename/line when a
        # sub-test fails in sok()
        return eval <<EOE;
#line $line $filename
    ok &t_cmp;
EOE
    }
}
