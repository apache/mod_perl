# this test tests PerlRequire configuration directive
########################################################################

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest ();

my %checks = (
    'default'                    => 'PerlRequired by Parent',
    'TestDirective::perlrequire' => 'PerlRequired by VirtualHost',
);

delete $checks{'TestDirective::perlrequire'} unless have_perl 'ithreads';

plan tests => scalar keys %checks;

for my $module (sort keys %checks) {
    Apache::TestRequest::module($module);

    my $config   = Apache::Test::config();
    my $hostport = Apache::TestRequest::hostport($config);
    t_debug("connecting to $hostport");

    ok t_cmp($checks{$module},
             $config->http_raw_get("/TestDirective::perlrequire", undef),
             "testing PerlRequire in $module");
}
