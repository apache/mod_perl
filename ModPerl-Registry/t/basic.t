use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my @modules = qw(registry registry_ng registry_bb perlrun);

plan tests => scalar @modules * 3;

my $cfg = Apache::Test::config();

# very basic compilation/response test
for my $module (@modules) {
    my $url = "/$module/basic.pl";

    ok t_cmp(
             "ok",
             $cfg->http_raw_get($url),
             "basic cgi test",
            );
}

# test non-executable bit
for my $module (@modules) {
    my $url = "/$module/not_executable.pl";

    ok t_cmp(
             "403 Forbidden",
             HEAD($url)->status_line(),
             "non-executable file",
            );
}

# test environment pre-set
for my $module (@modules) {
    my $url = "/$module/env.pl?foo=bar";

    ok t_cmp(
             "foo=bar",
             $cfg->http_raw_get($url),
             "mod_cgi-like environment pre-set",
            );
}

# chdir is not safe yet!
#
# require (actually chdir test)
#for my $module (@modules) {
#    my $url = "/$module/require.pl";

#    ok t_cmp(
#             "it works",
#             $cfg->http_raw_get($url),
#             "mod_cgi-like environment pre-set",
#            );
#}

