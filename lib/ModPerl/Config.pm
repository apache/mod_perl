package ModPerl::Config;

use strict;
use lib qw(Apache-Test/lib);

use Apache::Build ();
use Apache::TestConfig ();

sub config_as_str{
    my $build_config = Apache::Build->build_config;

    my $cfg = '';

    $cfg .= "*** using $INC{'Apache/BuildConfig.pm'}\n";

    $cfg .= "*** Makefile.PL options:\n";
    $cfg .= join '',
        map {sprintf "    %-20s => %s\n", $_, $build_config->{$_}}
            grep /^MP_/, sort keys %$build_config;

    my $test_config = Apache::TestConfig->new;
    my $httpd = $test_config->{vars}->{httpd};
    my $command = "$httpd -v";
    $cfg .= "\n\n*** $command\n";
    $cfg .= qx{$command};

    my $perl = $build_config->{MODPERL_PERLPATH};
    $command = "$perl -V";
    $cfg .= "\n\n*** $command\n";
    $cfg .= qx{$command};

    return $cfg;

}

1;
__END__

=pod

=head1 NAME - ModPerl::Config

=head1 DESCRIPTION

Functions to retrieve mod_perl specific env information.

=cut

