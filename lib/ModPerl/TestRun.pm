package ModPerl::TestRun;

use strict;
use warnings FATAL => 'all';

use base qw(Apache::TestRunPerl);

# some mp2 tests require more than one server instance to be available
# without which the server may hang, waiting for the single server
# become available
use constant MIN_MAXCLIENTS => 2;

use Apache::Build;
my $build = Apache::Build->build_config;

sub new_test_config {
    my $self = shift;

    # timeout in secs (threaded mpms are extremely slow to startup,
    # due to a slow perl_clone operation)
    $self->{conf_opts}->{startup_timeout} =
        $build->mpm_is_threaded() ? 180 : 120;

    $self->{conf_opts}->{maxclients} ||= MIN_MAXCLIENTS;

    ModPerl::TestConfig->new($self->{conf_opts});
}

sub bug_report {
    my $self = shift;

    print <<EOI;
+--------------------------------------------------------+
| Please file a bug report: http://perl.apache.org/bugs/ |
+--------------------------------------------------------+
EOI
}

package ModPerl::TestConfig;

use base qw(Apache::TestConfig);

# don't inherit LoadModule perl_module from the apache httpd.conf
sub should_skip_module {
    my($self, $name) = @_;

    $name eq 'mod_perl.c' ? 1 : $self->SUPER::should_skip_module($name);
}

1;

