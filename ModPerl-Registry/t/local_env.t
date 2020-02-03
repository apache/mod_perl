# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;
use Apache::TestConfig ();

use Apache2::Build ();

my $mpm_is_threaded = Apache2::Build->build_config->mpm_is_threaded();

my %modules = (
    registry         => 'ModPerl::Registry',
    perlrun          => 'ModPerl::PerlRun',
    registry_prefork => 'ModPerl::RegistryPrefork',
    perlrun_prefork  => 'ModPerl::PerlRunPrefork',
);

my @aliases = sort keys %modules;

plan tests => 2*@aliases, need 'mod_alias.c',
    { "can't run under threaded MPMs" => !$mpm_is_threaded };

my $script = "local_env.pl";
for my $alias (qw(registry_prefork perlrun_prefork registry perlrun)) {
    my $url = "/$alias/$script?MOD_PERL_API_VERSION";
    ok t_cmp GET_BODY($url), '2';
    ok t_cmp GET_BODY($url), '2';
}
