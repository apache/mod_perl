use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(GET GET_BODY HEAD);
use Apache::TestConfig ();

my %modules = (
    registry    => 'ModPerl::Registry',
    registry_bb => 'ModPerl::RegistryBB',
    perlrun     => 'ModPerl::PerlRun',
);

my @aliases = sort keys %modules;

plan tests => @aliases * 4 + 3;

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
    if (Apache::TestConfig::WIN32) {
        skip "non-executable bit test for Win32", 0;
        next;
    }
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

# test mod_perl api usage
{
    my $url = "/registry/content_type.pl";
    ok t_cmp(
        "ok",
        GET_BODY($url),
        "\$r->content_type('text/plain')",
    );
}


# test that files with .html extension, which are configured to run as
# scripts get the headerparse stage working: the default mime handler
# sets $r->content_type for .html files, so we can't rely on
# content_type not being set in making the decision whether to parse
# headers or not
{
    my $url = "/registry/send_headers.html";
    my $res = GET $url;
    ok t_cmp(
        "text/plain",
        $res->content_type,
        "script's content-type",
    );
}
