package Apache::test;

use strict;
use vars qw(@EXPORT $USE_THREAD);
use Exporter ();
use Config;
*import = \&Exporter::import;

@EXPORT = qw(test fetch simple_fetch have_module skip_test 
	     $USE_THREAD WIN32 grab); 

BEGIN { 
    if(not $ENV{MOD_PERL}) {
	eval { require "net/config.pl"; }; #for 'make test'
    } 
}

$USE_THREAD = ($Config{extensions} =~ /Thread/) || $Config{usethreads};

my $Is_Win32 = ($^O eq "MSWin32");
sub WIN32 () { $Is_Win32 };

my $UA;

eval {
    require LWP::UserAgent;
    $UA = LWP::UserAgent->new;
};

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
    unless ($url =~ /^http/) {
	$url = "http://$net::httpserver${url}";
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

sub grab {
    require IO::Socket;
    my(@args) = @_;
    @args = @ARGV unless @args;

    unless (@args > 0) { 
	die "usage: grab host:port path";
    }

    my($host, $port) = split ":", shift @args;
    $port ||= 80;
    my $url = shift @args || "/";

    my $remote = IO::Socket::INET->new(Proto     => "tcp",
				       PeerAddr  => $host,
				       PeerPort  => $port,
				       );
    unless ($remote) {
	die "cannot connect to http daemon on $host"; 
    }
    $remote->autoflush(1);
    print $remote "GET $url HTTP/1.0\n\n";
    my $response_line = 0;
    my $header_terminator = 0;
    my @msg = ();

    while ( <$remote> ) {
	#e.g. HTTP/1.1 200 OK
	if(m:^(HTTP/\d+\.\d+)[ \t]+(\d+)[ \t]*([^\012]*):i) {
	    push @msg, $_;
	    $response_line = 1;
	}
	elsif(/^([a-zA-Z0-9_\-]+)\s*:\s*(.*)/) {
	    push @msg, $_;
	}
	elsif(/^\015?\012$/) {
	    $header_terminator = 1;
	    push @msg, $_;
	}

	print;
    }
    close $remote;

    print "~" x 40, "\n", "Diagnostics:\n";
    if ($response_line and $header_terminator) {
	print " HTTP response is valid:\n";
    }
    else {
	print "     GET -> http://$host:$port$url\n";
	print " >>> No response line\n" unless $response_line;
	print " >>> No header terminator\n" unless $header_terminator;
	print " *** HTTP response is malformed\n";
    }
    print "-" x 40, "\n", @msg, "-" x 40, "\n";
}

1;

__END__
