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
	eval { require "net/config.pl"; }; #for 'make test'
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

sub run {
    require Test::Harness;
    my $self = shift;
    my $args = shift || {};
    my @tests = ();

    # First we check if we already are within the "t" directory
    if (-d "t") {
	# try to move into test directory
	chdir "t" or die "Can't chdir: $!";

	# fix all relative library locations
	foreach (@INC) {
	    $_ = "../$_" unless m,^(/)|([a-f]:),i;
	}
    }

    # Pick up the library files from the ../blib directory
    unshift(@INC, "../blib/lib", "../blib/arch");
    #print "@INC\n";

    $Test::Harness::verbose = shift(@ARGV)
	if $ARGV[0] =~ /^\d+$/ || $ARGV[0] eq "-v";

    $Test::Harness::verbose ||= $args->{verbose};

    if (@ARGV) {
	for (@ARGV) {
	    if (-d $_) {
		push(@tests, <$_/*.t>);
	    } 
	    else {
		$_ .= ".t" unless /\.t$/;
		push(@tests, $_);
	    }
	}
    } 
    else {
	push @tests, <*.t>, map { <$_/*.t> } @{ $args->{tdirs} || [] };
    }

    Test::Harness::runtests(@tests);
}

sub MM_test {
    my $script = "t/TEST";
    my $my_test = q(

test:	run_tests

);

    join '', qq(
MP_TEST_SCRIPT=$script
),
    q(
TEST_VERBOSE=0

kill_httpd:
	kill `cat t/logs/httpd.pid`

start_httpd: 
	./httpd -X -d `pwd`/t &

rehttpd:   kill_httpd start_httpd

run_tests:
	$(FULLPERL) $(MP_TEST_SCRIPT) $(TEST_VERBOSE)

),

$my_test;

}

1;

__END__
