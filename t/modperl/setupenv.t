use strict;
use warnings FATAL => 'all';

use Apache::TestRequest qw(GET_BODY_ASSERT);
use Apache::Test;
use Apache::TestUtil;

my $module   = "TestModperl::setupenv";
Apache::TestRequest::module($module);

my $config   = Apache::Test::config();
my $hostport = Apache::TestRequest::hostport($config);
my $path     = Apache::TestRequest::module2path($module);

my $base = "http://$hostport/$path";

t_debug("connecting to $base");

my @locations = ("${base}_mpdefault",
                 "${base}_mpsetup",
                 "${base}_mpdefault",  # make sure %ENV is cleared
                 "${base}_mpvoid",
                 "${base}_mpsetupvoid",
                 "${base}_psdefault",
                 "${base}_psnosetup",
                 "${base}_psvoid",
                 "${base}_psnosetupvoid");

# plan the tests from a handler so we can run
# tests from within handlers across multiple requests
#
# this requires keepalives and a per-connection interpreter
# to make certain we can plan in one request and test in another
# which requires LWP
unless (have_lwp()) {
    plan tests => 63, 0;
}

Apache::TestRequest::user_agent(keep_alive => 1);
print GET_BODY_ASSERT join '?', $base, scalar @locations;

# this tests for when %ENV is populated with CGI variables
# as well as the contents of the subprocess_env table
#
# see setupenv.pm for a full description of the tests

foreach my $location (@locations) {

    t_debug("trying $location");

    print GET_BODY_ASSERT $location;
}
