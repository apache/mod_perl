package Apache::test;

use strict;
use vars qw(@EXPORT $USE_THREAD);
use LWP::UserAgent ();
use Exporter ();
use Config;
*import = \&Exporter::import;

@EXPORT = qw(test fetch simple_fetch have_module skip_test $USE_THREAD); 

BEGIN { 
    if(not $ENV{MOD_PERL}) {
	require "net/config.pl";
    } 
}

$USE_THREAD = $Config{extensions} =~ /Thread/;

my $UA = LWP::UserAgent->new;

unless (defined &Apache::bootstrap) {
    *Apache::bootstrap = sub {};
    *Apache::Constants::bootstrap = sub {};
}

sub test { 
    my $s = $_[1] ? "ok $_[0]\n" : "not ok $_[0]\n";
    if($ENV{MOD_PERL}) {
	Apache->request->print($s);
    }
    else {
	print $s;
    }
}

sub fetch {
    my($ua, $url);
    if(@_ == 1) {
	$url = shift;
	$ua = $UA;
    }
    else {
	($ua, $url) = @_;
    }
    my $request = new HTTP::Request('GET', $url);
    my $response = $ua->request($request, undef, undef);
    $response->content;
}

sub simple_fetch {
    my $ua = LWP::UserAgent->new;
    my $url = URI::URL->new("http://$net::httpserver");
    $url->path(shift);
    my $request = new HTTP::Request('GET', $url);
    my $response = $ua->request($request, undef, undef);   
    $response->is_success;
}

sub have_module {
    my $mod = shift;
    my $v = shift;
    {# surpress "can't boostrap" warnings
	 local $SIG{__WARN__} = sub {};
	 require Apache;
	 require Apache::Constants;
     }  
    eval "require $mod";
    if($v) {
	eval { 
	    local $SIG{__WARN__} = sub {};
	    $mod->UNIVERSAL::VERSION($v);
	};
	if($@) {
	    warn $@;
	    return 0;
	}
    }
    if($@ && ($@ =~ /Can.t locate/)) {
	return 0;
    }
    elsif($@ && ($@ =~ /Can.t find loadable object for module/)) {
	return 0;
    }
    elsif($@) {
	warn "$@\n";
    }
    print "module $mod is installed\n";
    return 1;
}

sub skip_test {
    print "1..0\n";
    exit;
}

1;

__END__
