BEGIN {
    #./blib/lib:./blib/arch
    use ExtUtils::testlib;

    use lib './t/docs';
    require "blib.pl" if -e "./t/docs/blib.pl";
    $Apache::ServerStarting or warn "Server is not starting !?\n";
}

{
    last;
    Apache::warn("use Apache 'warn' is ok\n");

    my $s = Apache->server;

    my($host,$port) = map { $s->$_() } qw(server_hostname port);
    $s->log_error("starting server $host on port $port");

    my $admin = $s->server_admin;
    $s->warn("report any problems to server_admin $admin");
}

#use HTTP::Status ();
#use Apache::Symbol ();
#Apache::Symbol->make_universal;

$Apache::DoInternalRedirect = 1;
$Apache::ERRSV_CAN_BE_HTTP  = 1;

#warn "ServerStarting=$Apache::ServerStarting\n";
#warn "ServerReStarting=$Apache::ServerReStarting\n";

#use Apache::Debug level => 4;
use mod_perl 1.03_01;

if(defined &main::subversion) {
    die "mod_perl.pm is broken\n";
}

if($ENV{PERL_TEST_NEW_READ}) {
    *Apache::READ = \&Apache::new_read;
}

$ENV{KeyForPerlSetEnv} eq "OK" or warn "PerlSetEnv is broken\n";

#test Apache::RegistryLoader
{
    use Cwd ();
    use Apache::RegistryLoader ();
    use DirHandle ();
    use strict;
    
    local $^W = 0; #shutup line 164 Cwd.pm 

    my $cwd = Cwd::getcwd;
    my $rl = Apache::RegistryLoader->new(trans => sub {
	my $uri = shift; 
	$cwd."/t/net${uri}";
    });

    my $d = DirHandle->new("t/net/perl");

    for my $file ($d->read) {
	next if $file eq "hooks.pl"; 
	next unless $file =~ /\.pl$/;
	my $status = $rl->handler("/perl/$file");
	unless($status == 200) {
	    die "pre-load of `/perl/$file' failed, status=$status\n";
	}
    }
}

#for testing perl mod_include's

$Access::Cnt = 0;
sub main::pid { print $$ }
sub main::access { print ++$Access::Cnt }

$ENV{GATEWAY_INTERFACE} =~ /^CGI-Perl/ or die "GATEWAY_INTERFACE not set!";

#will be redef'd during tests
sub PerlTransHandler::handler {-1}

#for testing PERL_HANDLER_METHODS
#see httpd.conf and t/docs/LoadClass.pm

use LoadClass ();
sub MyClass::method ($$) {
    my($class, $r) = @_;  
    #warn "$class->method called\n";
    0;
}

sub BaseClass::handler ($$) {
    my($class, $r) = @_;  
    #warn "$class->handler called\n";
    0;
}

{
    package BaseClass;
    #so 5.005-tobe doesn't complain:
    #No such package "BaseClass" in @ISA assignment at ...
}


$MyClass::Object = bless {}, "MyClass";
@MyClass::ISA = qw(BaseClass);

#testing child init/exit hooks

sub My::child_init {
    my $r = shift;
    my $s = $r->server;
    my $sa = $s->server_admin;
    $s->warn("[notice] child_init for process $$, report any problems to $sa\n");
}

sub My::child_exit {
    warn "[notice] child process $$ terminating\n";
}

sub My::restart {
    my $r = shift;
    my $s = $r->server;
    my $sa = $s->server_admin;
    push @HTTP::Status::ISA, "Apache::Symbol";
    HTTP::Status->undef_functions;
}

sub Apache::AuthenTest::handler {
    use Apache::Constants ':common';
    my $r = shift;

    $r->custom_response(AUTH_REQUIRED, "/error.txt");

    my($res, $sent_pwd) = $r->get_basic_auth_pw;
    return $res if $res; #decline if not Basic

    my $user = lc $r->connection->user;
    $r->notes("DoAuthenTest", 1);

    unless($user eq "dougm" and $sent_pwd eq "mod_perl") {
        $r->note_basic_auth_failure;
        return AUTH_REQUIRED;
    }

    return OK;                       
}

sub My::ProxyTest::handler {
    my $r = shift;
    unless ($r->proxyreq and $r->uri =~ /proxytest/) {
	#warn sprintf "ProxyTest: proxyreq=%d, uri=%s\n",
	$r->proxyreq, $r->uri;
    }
    return -1 unless $r->proxyreq;
    return -1 unless $r->uri =~ /proxytest/;
    $r->handler("perl-script");
    $r->push_handlers(PerlHandler => sub {
	my $r = shift;
	$r->send_http_header("text/plain");
	$r->print("1..1\n");
	$r->print("ok 1\n");
	$r->print("URI=`", $r->uri, "'\n");
    });
    return 0;
}

if(Apache->can_stack_handlers) {
    Apache->push_handlers(PerlChildExitHandler => sub {
	warn "[notice] push'd PerlChildExitHandler called, pid=$$\n";
    });
}

END {
    warn "[notice] END block called for startup.pl\n";
}

package Destruction;

sub new { bless {} }

sub DESTROY { 
    warn "[notice] Destruction->DESTROY called for \$global_object\n" 
}

#prior to 1.3b1 (and the child_exit hook), this object's DESTROY method would not be invoked
$global_object = Destruction->new;

1;
