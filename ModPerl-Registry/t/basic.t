use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my %modules = 
    (registry    => 'ModPerl::Registry',
     registry_ng => 'ModPerl::RegistryNG',
     registry_bb => 'ModPerl::RegistryBB',
     perlrun     => 'ModPerl::PerlRun',
    );

my @aliases = sort keys %modules;

plan tests => @aliases * 3;

my $cfg = Apache::Test::config();

# very basic compilation/response test
for my $alias (@aliases) {
    my $url = "/$alias/basic.pl";

    ok t_cmp(
             "ok",
             $cfg->http_raw_get($url),
             "$modules{$alias} basic cgi test",
            );
}

# test non-executable bit
for my $alias (@aliases) {
    my $url = "/$alias/not_executable.pl";

    ok t_cmp(
             "403 Forbidden",
             HEAD($url)->status_line(),
             "$modules{$alias} non-executable file",
            );
}

# test environment pre-set
for my $alias (@aliases) {
    my $url = "/$alias/env.pl?foo=bar";

    ok t_cmp(
             "foo=bar",
             $cfg->http_raw_get($url),
             "$modules{$alias} mod_cgi-like environment pre-set",
            );
}

# chdir is not safe yet!
#
# require (actually chdir test)
#for my $alias (@aliases) {
#    my $url = "/$alias/require.pl";

#    ok t_cmp(
#             "it works",
#             $cfg->http_raw_get($url),
#             "$modules{$alias} mod_cgi-like environment pre-set",
#            );
#}

