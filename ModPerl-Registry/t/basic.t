use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(GET_BODY HEAD);

my %modules = (
    registry    => 'ModPerl::Registry',
    registry_bb => 'ModPerl::RegistryBB',
    perlrun     => 'ModPerl::PerlRun',
);

my @aliases = sort keys %modules;

plan tests => @aliases * 4 + 1;

# very basic compilation/response test
for my $alias (@aliases) {
    my $url = "/$alias/basic.pl";

    ok t_cmp(
        "ok",
        GET_BODY($url),
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
        GET_BODY($url),
        "$modules{$alias} mod_cgi-like environment pre-set",
    );
}

# require (actually chdir test)
for my $alias (@aliases) {
    my $url = "/$alias/require.pl";

    ok t_cmp(
        "it works",
        GET_BODY($url),
        "$modules{$alias} mod_cgi-like environment pre-set",
    );
}

# test method handlers
{
    my $url = "/registry_oo_conf/env.pl?foo=bar";
    ok t_cmp(
        "foo=bar",
        GET_BODY($url),
        "ModPerl::Registry->handler mod_cgi-like environment pre-set",
    );
}
