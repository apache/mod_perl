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

    #XXX: issue for these is they need to happen after PerlSwitches

    #XXX: this should only be done for the modperl-2.0 tests
    my $htdocs = $self->{vars}{documentroot};
    $self->postamble(<<"EOF");
<Perl >
push \@Alias, ['/perl_sections', '$htdocs'],
\$Location{'/perl_sections'} = {
	'PerlInitHandler' => 'ModPerl::Test::add_config',
	'AuthType' => 'Basic',
	'AuthName' => 'PerlSection',
	'PerlAuthenHandler' => 'TestHooks::authen',
	};
</Perl>
EOF

    #XXX: this should only be done for the modperl-2.0 tests
    $self->postamble(<<'EOF');
PerlLoadModule TestDirective::loadmodule

MyTest one two
ServerTest per-server

<Location /TestDirective::loadmodule>
    MyOtherTest value
</Location>
EOF

	#XXX: this should only be done for the modperl-2.0 tests
	$self->postamble(<<'EOF');
	Perl $TestDirective::perl::worked="yes";
EOF

    #XXX: this should only be done for the modperl-2.0 tests
    $self->postamble(<<'EOF');
=pod
This is some pod data
=over apache
PerlSetVar TestDirective__pod_over_worked yes
=back
This is some more pod
=cut
PerlSetVar TestDirective__pod_cut_worked yes
EOF
    
}

1;

