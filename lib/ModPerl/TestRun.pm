package ModPerl::TestRun;

use Apache::TestRunPerl ();

our @ISA = qw(Apache::TestRunPerl);

sub new_test_config {
    my $self = shift;

    ModPerl::TestConfig->new($self->{conf_opts});
}

package ModPerl::TestConfig;

our @ISA = qw(Apache::TestConfig);

#don't inherit LoadModule perl_module from the apache httpd.conf

sub should_load_module {
    my($self, $name) = @_;

    $name eq 'mod_perl.c' ? 0 : $self->SUPER::should_load_module($name);
}

1;

