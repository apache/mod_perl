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

my @modules = qw(registry registry_ng registry_bb perlrun);

plan tests => 6;

my $cfg = Apache::Test::config();

my $file = 'closure.pl';
my $path = catfile $cfg->{vars}->{serverroot}, 'cgi-bin', $file;

# for all sub-tests in this test, we assume that we always get onto
# the same interpreter (since there are no other requests happening in
# parallel

{
    # ModPerl::PerlRun
    # always flush
    # no cache

    my $url = "/same_interp/perlrun/$file";
    my $same_interp = Apache::TestRequest::same_interp_tie($url);

    # should be no closure effect, always returns 1
    my $first  = req($same_interp, $url);
    my $second = req($same_interp, $url);
    ok t_cmp(
             0,
             $first && $second && ($second - $first),
             "never the closure problem",
            );

    # modify the file
    sleep_and_touch_file($path);

    # it doesn't matter, since the script is not cached anyway
    ok t_cmp(
             1,
             req($same_interp, $url),
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
    my $first  = req($same_interp, $url);
    my $second = req($same_interp, $url);
    ok t_cmp(
             1,
             $second - $first,
             "the closure problem should exist",
            );

    # modify the file
    sleep_and_touch_file($path);

    # should no notice closure effect on the first request
    ok t_cmp(
             1,
             req($same_interp, $url),
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
    my $first  = req($same_interp, $url);
    my $second = req($same_interp, $url);
    ok t_cmp(
             1,
             $second - $first,
             "the closure problem should exist",
            );

    # modify the file
    sleep_and_touch_file($path);

    # modification shouldn't be noticed
    my $third = req($same_interp, $url);
    ok t_cmp(
             1,
             $third - $second,
             "no reload on mod, the closure problem persists",
            );

}

sub sleep_and_touch_file {
    my $file = shift;
    # need to wait at least 1 whole sec, so -M will notice the
    # difference. select() has better resolution than 1 sec as in
    # sleep()
    select undef, undef, undef, 1.00; # sure 1 sec
    my $now = time;
    utime $now, $now, $file;
}

sub req {
    my($same_interp, $url) = @_;
    my $res = Apache::TestRequest::same_interp_do($same_interp,
                                                  \&GET, $url);
    return $res ? $res->content : undef;
}
