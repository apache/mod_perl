package TestCompat::apache_module;

# Apache::Module compat layer tests

use strict;
use warnings FATAL => 'all';

use Apache::TestUtil;
use Apache::Test;

use Apache::compat ();
use Apache::Constants qw(OK);

our @APACHE_MODULE_COMMANDS = (
    {
        name => 'TestCompatApacheModuleParms',
    },
);

sub TestCompatApacheModuleParms {
    my($self, $parms, $args) = @_;
    my $config = Apache::Module->get_config($self, $parms->server);
    $config->{data} = $args;
}

sub handler : method {
    my($self, $r) = @_;

    plan $r, tests => 2;

    my $top_module = Apache::Module->top_module();
    ok t_cmp (ref($top_module), 'Apache::Module');

    my $config = Apache::Module->get_config($self, $r->server);
    ok t_cmp ($config->{data}, 'Test');

    OK;
}

1;
__END__

# APACHE_TEST_CONFIG_ORDER 950

<Base>
PerlLoadModule TestCompat::apache_module
</Base>
TestCompatApacheModuleParms "Test"
