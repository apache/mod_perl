package ModPerl::Config;

use strict;
use lib qw(Apache-Test/lib);

use Apache::Build ();
use Apache::TestConfig ();

sub config_as_str{
    my $build_config = Apache::Build->build_config;

    my $cfg = '';

    $cfg .= "*** using $INC{'Apache/BuildConfig.pm'}\n";

    # the widest key length
    my $max_len = 0;
    for (map {length} grep /^MP_/, keys %$build_config) {
        $max_len = $_ if $_ > $max_len;
    }

    # mod_perl opts
    $cfg .= "*** Makefile.PL options:\n";
    $cfg .= join '',
        map {sprintf "  %-${max_len}s => %s\n", $_, $build_config->{$_}}
            grep /^MP_/, sort keys %$build_config;

    my $command = '';

    # httpd opts
    my $test_config = Apache::TestConfig->new;
    if (my $httpd = $test_config->{vars}->{httpd}) {
        $command = "$httpd -V";
        $cfg .= "\n\n*** $command\n";
        $cfg .= qx{$command};
    } else {
        $cfg .= "\n\n*** The httpd binary was not found\n";
    }

    # perl opts
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

