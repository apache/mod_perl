use strict;
use warnings FATAL => 'all';

use ModPerl::Registry;
use Apache::Test;
use File::Spec::Functions;
use Apache::TestUtil;

# this test tests how various registry packages cache and flush the
# scripts their run, and whether they check modification on the disk
# or not

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

    my $url = "/perlrun/$file";

    # should be no closure effect, always returns 1
    my $first  = $cfg->http_raw_get($url);
    my $second = $cfg->http_raw_get($url);
    ok t_cmp(
             0,
             $second - $first,
             "never a closure problem",
            );

    # modify the file
    sleep_and_touch_file($path);

    # it doesn't matter, since the script is not cached anyway
    ok t_cmp(
             1,
             $cfg->http_raw_get($url),
             "never a closure problem",
            );

}



{
    # ModPerl::Registry
    # no flush
    # cache, but reload on modification
    my $url = "/registry/$file";

    # we don't know what other test has called this uri before, so we
    # check the difference between two subsequent calls. In this case
    # the difference should be 1.
    my $first  = $cfg->http_raw_get($url);
    my $second = $cfg->http_raw_get($url);
    ok t_cmp(
             1,
             $second - $first,
             "closure problem should exist",
            );

    # modify the file
    sleep_and_touch_file($path);

    # should no notice closure effect on first request
    ok t_cmp(
             1,
             $cfg->http_raw_get($url),
             "no closure on the first request",
            );

}




{
    # ModPerl::RegistryBB
    # no flush
    # cache once, don't check for mods
    my $url = "/registry_bb/$file";

    # we don't know what other test has called this uri before, so we
    # check the difference between two subsequent calls. In this case
    # the difference should be 0.
    my $first  = $cfg->http_raw_get($url);
    my $second = $cfg->http_raw_get($url);
    ok t_cmp(
             1,
             $second - $first,
             "closure problem should exist",
            );

    # modify the file
    sleep_and_touch_file($path);

    # 
    my $third = $cfg->http_raw_get($url);
    ok t_cmp(
             1,
             $third - $second,
             "no reload on mod, closure persist",
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
