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

    $name eq 'mod_perl.c' ? 0 : 1;
}

sub configure_startup_pl {
    my $self = shift;

    $self->SUPER::configure_startup_pl;

    #XXX: this should only be done for the modperl-2.0 tests
    $self->postamble(<<'EOF');
<Perl handler=ModPerl::Test::perl_section>
    $Foo = 'bar';
</Perl>
EOF
}

1;

