#PerlOpmask default

<IfModule mod_dll.c>
LoadModule perl_module modules/ApacheModulePerl.dll
</IfModule>

AddType text/x-server-parsed-html .shtml
AddType text/perl-module .pm

Action text/perl-module /perl/action.pl

PerlPassEnv TEST_PERL_DIRECTIVES

#these three are passed to perl_parse(), 
#which happens before <Perl> sections are processed
#optionally, they can be inside <Perl>, however for testing we want
#warnings and taint checks on while processing <Perl>
#besides that, we rely on the PerlScript below to set @INC to our blib

PerlScript docs/startup.pl
PerlScript docs/stacked.pl

#-Tw
PerlTaintCheck On
PerlWarn On

PerlSetVar KeyForPerlSetVar OK
PerlSetEnv KeyForPerlSetEnv OK

<Perl>
#!perl
use Apache ();
use Apache::Registry ();
use Apache::RegistryNG ();

Apache::Server->register_cleanup(sub { 
    warn "Apache::Server registered cleanup called for $$\n";
});

if($ENV{TEST_PERL_DIRECTIVES}) {
    #t/TestDirectives/TestDirectives.pm
    push @INC, map { "t/TestDirectives/blib/$_" } qw(arch lib);
    require Apache::TestDirectives;
    require Apache::ExtUtils;
 
    my $proto_perl2c = Apache::ExtUtils->proto_perl2c;

    $PerlConfig .= "YAC yet another\n";

    $PerlConfig .= "<Location /perl>\n";
    while(my($pp,$cp) = each %$proto_perl2c) {
	my $arg = "A";
	$pp =~ s/^\$\$//;
	1 while $pp =~ s/(\$|\@)/$arg++ . " "/ge;
	$PerlConfig .= "$cp $pp\n";
    }

    $PerlConfig .= <<EOF;
TestCmd one two
AnotherCmd
CmdIterate A B C D E F
</Location>
<Container /for/whatever>

it's  
  miller
time
#make that a scotch
</Container>

<Location /perl/io>
TestCmd PerlIO IsStdio
</Location>
EOF
}

$My::config_is_perl = 1;

my $dir = $Apache::Server::CWD;
$dir .= "/t"; # if -d "t";
my $Is_Win32 = ($^O eq "MSWin32");

sub prompt ($;$) {
    my($mess,$def) = @_;
    print "$mess [$def]";
    STDIN->untaint;
    chomp(my $ans = <STDIN>);
    $ans || $def;
}

$ServerRoot = $dir;

$User  = $Is_Win32 ? "nobody" : (getpwuid($>) || $>);
$Group = $Is_Win32 ? "nogroup" : (getgrgid($)) || $)); 

if($User eq "root") {
    my $other = (getpwnam('nobody'))[0];
    $User = $other if $other;
} 
if($User eq "root") {
    print "Cannot run tests as User `$User'\n";
    $User  = prompt "Which User?", "nobody";
    $Group = prompt "Which Group?", $Group; 
}
print "Will run tests as User: '$User' Group: '$Group'\n";

require 'net/config.pl';
my $srv = $net::httpserver;
($srv = $net::httpserver) =~ s/\D+$//;
$Port = (split ":", $srv, 2)[1];
$Port ||= 8529;
print "Will bind to Port $Port\n";

$DocumentRoot = "$dir/docs";
$ServerName = "localhost";

push @AddType, ["text/x-server-parsed-html" => ".shtml"];
 
for (qw(/perl /cgi-bin /dirty-perl /perl_xs)) {
    push @Alias, [$_ => "$dir/net/perl/"];
}

my @mod_perl = (
    SetHandler  => "perl-script",
    PerlHandler => "Apache::RegistryNG->handler",
    Options     => "ExecCGI",
);

$Location{"/dirmagic"} = {
    PerlHandler => "My::DirIndex",
};

$Location{"/dirty-perl"} = { 
    SetHandler => "perl-script",
    PerlHandler => "Apache::PerlRun",
    Options => "+ExecCGI ",
    PerlSendHeader => "On",
};

for (qw(perl perl_xs)) {
    $Location{"/$_"} = { 
	@mod_perl,
	PerlSetEnv => [KeyForPerlSetEnv => "OK"],
        #PerlSetVar => [KeyForPerlSetVar => "OK"],
    };
}

for (qw(perl perl_xs)) {
    $Location{"/$_/noenv"} = { 
	@mod_perl,
	PerlSetupEnv => "Off",
    };
}

$Location{"/cgi-bin"} = {
    SetHandler => "cgi-script",
    Options    => "ExecCGI",
};

$VirtualHost{"localhost"} = {
    Location => {
	"/perl/io" => {
	    @mod_perl,
	    PerlSendHeader => "On",
	    PerlSetupEnv   => "On",
	},
	"/perl_xs/io" => {
	    @mod_perl,
	    PerlSendHeader => "On",
	    PerlSetupEnv   => "On",
	},
    },
};

#$Location{"/perl/io"} = {
#    @mod_perl,
#    PerlSendHeader => "On",
#    PerlSetupEnv   => "On",
#};

for (qw(perl perl_xs)) {
    $Location{"/$_/perl-status"} = {
	SetHandler  => "perl-script",
	PerlHandler => "Apache::Status",
    };
}

for (qw(status info)) {
    $Location{"/server-$_"} = {
	SetHandler => "server-$_",
    };
}

$ErrorLog = "logs/mod_perl_error_log";
$PidFile  = "logs/mod_perl_httpd.pid";

$AccessConfig = $TypesConfig = $ScoreBoardFile = "$dir/docs/null.txt";

$LockFile = "logs/mod_perl.lock";

#push @PerlChildInitHandler, "My::child_init";
#push @PerlChildExitHandler, "My::child_exit";

$Location{"/STAGE"} = {
    ErrorDocument => [
	      [403 => "/stage-redir"],
	      [404 => "/stage-redir"],
    ],
};

$Location{"/stage-redir"} = {
    @mod_perl,
    PerlHandler => "Apache::Stage",
};

$PerlTransHandler =  "PerlTransHandler::handler";

$Location{"/chain"} = {
    @mod_perl,
    PerlHandler => [map { "Stacked::$_" } qw(one two three four)],
};

$Location{"/death"} = {
    @mod_perl,
    PerlHandler => "Apache::Death",
};

</Perl>

