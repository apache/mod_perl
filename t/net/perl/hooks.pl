use Apache ();
use Cwd 'fastcwd';
my $tests = 0;
my $pwd = fastcwd;

my $r = Apache->request;
$r->content_type("text/html");
$r->send_http_header;
my $doc_root = "$pwd/../../docs";
#Apache->untaint($doc_root);

my $ht_access  = "$doc_root/.htaccess";
my $hooks_file = "$doc_root/hooks.txt";
warn "hooks_file = $doc_root/hooks.txt ($pwd)\n";

unlink $ht_access;
unlink $hooks_file;

local *FH;
if(Apache::perl_hook("Authen")) {
    open FH, ">$ht_access";
    print FH <<EOF;
AuthType Basic
AuthName mod_perl tests

<Limit GET>
require valid-user
</Limit>

EOF
    close FH;
}


my($hook, $package, $retval);

for (qw(Access Authen Authz Fixup Cleanup
	HeaderParser Init Log Type Trans)) {
    next unless Apache::perl_hook($_);
    $tests++; 
    $retval = -1; #we want to decline Trans, but ok for Authen, etc.
    $hook = "Perl${_}Handler";
    $package = $hook; #"Apache::$hook";
    unless ($_ eq "Trans") { #must be in server configs
	$retval = 0;
	open FH, ">>$ht_access" or die "can't open $ht_access";
	print FH "$hook $package\n";
	close FH;
    }

    undef &{"$package\:\:handler"}; #avoid warnings
    eval <<"PACKAGE";
package $package;

sub $package\:\:handler {
    my(\$r) = \@_;
    return -1 unless \$r->is_main;
    open FH, ">>$hooks_file" or die "can't open $hooks_file";
    \$r->warn("$hook ok\n");
    print FH "$hook ok\n";
    close FH;
    return $retval;
}	

PACKAGE

    $r->print($@) if $@;
}

#if(Apache::perl_hook("Log") and Apache::perl_hook("Fixup")) {
#    undef &PerlLogHandler::handler;
#    @PerlLogHandler::ISA = qw(PerlFixupHandler);
#    $r->warn("PerlLogHandler isa PerlFixupHandler");
#}

$r->print($tests);



