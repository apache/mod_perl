package mod_perl;
use 5.003_97;
use strict;

BEGIN {
    $mod_perl::VERSION = "1.0701";
}

sub subversion {
    print qq( -DSERVER_SUBVERSION=\\"mod_perl/$mod_perl::VERSION\\" );
}

sub import {
    my $class = shift;

    #so we can say EXTRA_CFLAGS = `perl -Mmod_perl -e subversion`
    unless(exists $ENV{MOD_PERL}) {
	*main::subversion = \&subversion;
	return;
    }

    $ENV{MOD_PERL} = $mod_perl::VERSION;
    $ENV{GATEWAY_INTERFACE} = "CGI-Perl/1.1";

    return unless @_;

    if($_[0] =~ /^\d/) {
	$class->UNIVERSAL::VERSION(shift);
    }

    for my $hook (@_) {
	require Apache;
	my $enabled = Apache::perl_hook($hook); 
	next if $enabled > 0;
	if($enabled < 0) {
	    die "unknown mod_perl option `$hook'\n";
	}
	else {
	    (my $flag = $hook) =~ s/([A-Z])/_$1/g;
	    $flag = uc $flag;
	    die "`$hook' not enabled, rebuild mod_perl with PERL$flag=1\n";
	}
    }
}

1;

__END__
