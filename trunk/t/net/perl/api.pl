use Apache ();
use Apache::Constants qw(:server :common);
use Apache::test;
use strict;

Apache->register_cleanup(sub {0});
my $r;

if(Apache->module("Apache::Request")) {
    $r = Apache::Request->new;
}
else {
    $r = Apache->request;
}


my $is_xs = ($r->uri =~ /_xs/);

my $tests = 50;
my $is_win32 = WIN32;
++$tests unless $is_win32;
my $test_get_set = Apache->can('set_handlers') && ($tests += 4);
my $test_custom_response = (MODULE_MAGIC_NUMBER >= 19980324) && $tests++;
my $test_dir_config = $INC{'Apache/TestDirectives.pm'} && ($tests += 7);

my $i;

$r->content_type("text/plain");
$r->content_languages([qw(en)]);
$r->send_http_header;

$r->print("1..$tests\n");

#backward compat
%ENV = $r->cgi_env;
my $envk = keys %ENV;
#print "cgi_env ($envk):\n";
#print map { "$_ = $ENV{$_}\n" } keys %ENV;

$r->subprocess_env; #test void context
$envk = keys %ENV;
#print "subprocess_env ($envk):\n";
#print map { "$_ = $ENV{$_}\n" } keys %ENV;

test ++$i, $r->as_string;
print $r->as_string;
print "r == $r\n";
test ++$i, $r->filename eq $0;
test ++$i, -d $Apache::Server::CWD;
print "\$Apache::Server::CWD == $Apache::Server::CWD\n";
print "\$0 == $0\n";

unless ($is_win32) {
  my $ft_s = -s $INC{'Apache.pm'};
  $r->finfo;
  my $ft_def = -s _;
  print "Apache.pm == $ft_s, $0 == $ft_def\n";
  test ++$i, $ft_s != $ft_def;
}

my $loc = $r->location;
print "<Location $loc>\n";
test ++$i, $loc and $r->uri =~ m:^$loc:;

test ++$i, $r->get_remote_host;
test ++$i, $r->get_server_port;

test ++$i, SERVER_VERSION =~ /mod_perl/;

test ++$i, $r->last;
test ++$i, $ENV{GATEWAY_INTERFACE};
test ++$i, scalar $r->cgi_var('GATEWAY_INTERFACE');
test ++$i, defined($r->seqno);
test ++$i, $r->protocol;
#hostname
test ++$i, $r->status;
test ++$i, $r->status_line;
test ++$i, $r->method eq "GET";
#test ++$i, $r->method_number

$r->subprocess_env(SetKey => 'value');
test ++$i, $r->subprocess_env('SetKey') eq 'value';
my(%headers_in) = $r->headers_in;
test ++$i, keys %headers_in;
test ++$i, $r->header_in('UserAgent') || $r->header_in('User-Agent');
$r->header_in('X-Hello' => "goodbye");
test ++$i, $r->header_in("X-Hello") eq "goodbye";

$r->header_out('X-Camel-Message' => "I can fly"); 
test ++$i, $r->header_out("X-Camel-Message") eq "I can fly";
my(%headers_out) = $r->headers_out;
test ++$i, keys %headers_out;

my(%err_headers_out) = $r->headers_out;
test ++$i, keys %err_headers_out;
#test ++$i, $r->err_header_out("Content-Type");
$r->err_header_out('X-Die' => "uhoh"); 
test ++$i, $r->err_header_out("X-Die") eq "uhoh";

$r->notes("FOO", 1); 
$r->notes("ANoteKey", "TRUE");
test ++$i, $r->notes("ANoteKey");
test ++$i, $r->content_type;
test ++$i, $r->handler;

$r->header_out(ByeBye => "TRUE");
test ++$i, $r->header_out("ByeBye");
$r->header_out(ByeBye => undef);
test ++$i, not $r->header_out("ByeBye");

#content_encoding
test ++$i, $r->content_languages;
#no_cache
test ++$i, $r->uri;
test ++$i, $r->filename;
#test ++$i, $r->path_info;
#test ++$i, $r->query_string;

#just make sure we can actually call these
test ++$i, $r->satisfies || 1;
test ++$i, $r->some_auth_required || 1;

#dir_config

my $c = $r->connection;
test ++$i, $c;
test ++$i, $c->remote_ip;
test ++$i, $c->remote_addr;
test ++$i, $c->local_addr;

#Connection::remote_host
#Connection::remote_logname
#Connection::user
#Connection::auth_type

test ++$i, $r->server_root_relative;

my $s = $r->server;
test ++$i, $s;
test ++$i, $s->server_admin;
test ++$i, $s->server_hostname;
test ++$i, $s->port;

for (my $srv = $r->server; $srv; $srv = $srv->next) {
    my $name = $srv->server_hostname;
}

++$i;
my $str = "ok $i\n";
$r->print(\$str);

test ++$i, $r->module("Apache");
test ++$i, not Apache->module("Not::A::Chance");
test ++$i, Apache->module("Apache::Constants");
test ++$i, not Apache->module("mod_nochance.c");
test ++$i, Apache->module("mod_perl.c");

#just make sure we can call this one
if($test_custom_response) {
    test ++$i, $r->custom_response(403, "no chance") || 1;
}

if($test_get_set) {
    $r->set_handlers(PerlLogHandler => ['My::Logger']);
    my $handlers = $r->get_handlers('PerlLogHandler');
    test ++$i, @$handlers >= 1;
    $r->set_handlers(PerlLogHandler => undef);
    $handlers = $r->get_handlers('PerlLogHandler');
    test ++$i, @$handlers == 0;
    $handlers = $r->get_handlers('PerlHandler');
    test ++$i, @$handlers == 1;
    $r->set_handlers('PerlHandler', $handlers);

    $r->set_handlers(PerlTransHandler => DONE); #make sure a per-server config thing works
    $handlers = $r->get_handlers('PerlTransHandler');
    test ++$i, @$handlers == 0;
}

if($test_dir_config) {
    require Apache::ModuleConfig;
    my $dc = Apache::ModuleConfig->get($r);
    test ++$i, not $dc;

    for my $cv (
		sub {
		    package Apache::TestDirectives;
		    Apache::ModuleConfig->get(Apache->request);
		},
                sub {
		    Apache::ModuleConfig->get($r, "Apache::TestDirectives");
		})
    {
        my $cfg = $cv->();
        require Data::Dumper;
        $r->print(Data::Dumper::Dumper($cfg));
        test ++$i, "$cfg" =~ /HASH/;
        test ++$i, keys(%$cfg) >= 3;
        test ++$i, $cfg->{FromNew};
        unless ($cfg->{SetFromScript}) {
	    $cfg->{SetFromScript} = [$0,$$];
	}
    }
}

@My::Req::ISA = qw(Apache);

my $hr = bless {
    _r => $r,
}, "My::Req";

test ++$i, $hr->filename;
delete $hr->{_r};
my $uri;

eval { 
    $uri = $hr->uri;
};
test ++$i, not $uri;
print $@ if $@;

use Apache::test qw($USE_THREAD);
if ($USE_THREAD) {
    #under Solaris at least, according to Brian P Millett <bpm@ec-group.com>
    warn "XXX: need to fix \$r->exit in t/net/api w/ threads\n";
}
else {
    $r->exit unless $is_xs;
}




