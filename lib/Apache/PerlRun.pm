package Apache::PerlRun;

use strict;
use vars qw($Debug);
use Apache::Constants qw(:common OPT_EXECCGI);
use File::Basename ();
use IO::File ();
use Cwd ();

unless ($Apache::Registry::{NameWithVirtualHost}) {
    $Apache::Registry::NameWithVirtualHost = 1;
}

$Debug ||= 0;
my $Is_Win32 = $^O eq "MSWin32";

@Apache::PerlRun::ISA = qw(Apache);

sub new {
    my($class, $r) = @_;
    return $r unless ref($r) eq "Apache";
    if(ref $r) {
	$r->request($r);
    }
    else {
	$r = Apache->request;
    }
    my $filename = $r->filename;
    $r->log_error("Apache::PerlRun->new for $filename in process $$")
	if $Debug && $Debug & 4;

    bless $r, $class;
}

sub can_compile {
    my($r) = @_;
    my $filename = $r->filename;
    if (-r $filename && -s _) {
	if (!($r->allow_options & OPT_EXECCGI)) {
	    $r->log_reason("Options ExecCGI is off in this directory",
			   $filename);
	    return FORBIDDEN;
 	}
	if (-d _) {
	    $r->log_reason("attempt to invoke directory as script", $filename);
	    return FORBIDDEN;
	}
	unless (-x _ or $Is_Win32) {
	    $r->log_reason("file permissions deny server execution",
			   $filename);
	    return FORBIDDEN;
	}

	return wantarray ? (OK, -M _) : OK;
    }
    return NOT_FOUND;
}

sub compile {
    my($r, $eval) = @_;
    $r->log_error("Apache::PerlRun->compile") if $Debug && $Debug & 4;
    Apache->untaint($$eval);
    {
	no strict; #so eval'd code doesn't inherit our bits
	eval $$eval;
    }
}

sub namespace {
    my($r, $root) = @_;

    $r->log_error(sprintf "Apache::PerlRun->namespace escaping %s",
		  $r->uri) if $Debug && $Debug & 4;

    my $script_name = $r->path_info ?
	substr($r->uri, 0, length($r->uri)-length($r->path_info)) :
	    $r->uri;

    if($Apache::Registry::NameWithVirtualHost) {
	my $srv = $r->server;
	$script_name = join "", $srv->server_hostname, $script_name
	    if $srv->is_virtual;
    }

    # Escape everything into valid perl identifiers
    $script_name =~ s/([^A-Za-z0-9\/])/sprintf("_%2x",unpack("C",$1))/eg;

    # second pass cares for slashes and words starting with a digit
    $script_name =~ s{
			  (/+)       # directory
			  (\d?)      # package's first character
			 }[
			   "::" . ($2 ? sprintf("_%2x",unpack("C",$2)) : "")
			  ]egx;

    $Apache::Registry::curstash = $script_name if 
	scalar(caller) eq "Apache::Registry";

    $root ||= "Apache::ROOT";

    $r->log_error("Apache::PerlRun->namespace: package $root$script_name")
	if $Debug && $Debug & 4;

    return $root.$script_name;
}

sub readscript {
    my $r = shift;
    my $filename = $r->filename;
    $r->log_error("Apache::PerlRun->readscript $filename")
	    if $Debug && $Debug & 4;
    my $fh = IO::File->new($filename);
    local $/;
    my $code = <$fh>;
    return \$code;
}

sub error_check {
    my $r = shift;
    if ($@) {
	$r->log_error("PerlRun: `$@'");
	$@{$r->uri} = $@;
	$@ = ''; #XXX fix me, if we don't do this Apache::exit() breaks	
	return SERVER_ERROR;
    }
    return OK;
}

sub chdir_file {
    my $r = shift;
    my $cwd = Cwd::fastcwd();
    chdir File::Basename::dirname($r->filename);
    *0 = \$r->filename;
    return $cwd;
}

#XXX not good enough yet
my(%switches) = (
   'T' => sub {
       Apache::warn("Apache::PerlRun: T switch ignored, ".
		    "enable with 'PerlTaintCheck On'\n")
	   unless $Apache::__T; "";
   },
   'w' => sub { 'BEGIN {$^W = 1;}; $^W = 1;' },
);

sub parse_cmdline {
    my($r, $sub) = @_;
    my($line) = $$sub =~ /^(.*)$/m;
    my(@cmdline) = split /\s+/, $line;
    return $sub unless @cmdline;
    return $sub unless shift(@cmdline) =~ /^\#!/;
    my($s, @s, $prepend);
    $prepend = "";
    for $s (@cmdline) {
	next unless $s =~ s/^-//;
	last if substr($s,0,1) eq "-";
	for (split //, $s) {
	    next unless $switches{$_};
	    #print STDERR "parsed `$_' switch\n";
	    $prepend .= &{$switches{$_}};
	}
    }
    $$sub =~ s/^/$prepend/ if $prepend;
    return $sub;
}

sub handler {
    my $r = shift;

    my $rc = can_compile($r);
    return $rc unless $rc == OK;

    my $package = namespace($r);
    my $code = readscript($r);
    parse_cmdline($r, $code);

    my $cwd = chdir_file($r);

    my $eval = join '',
		    'package ',
		    $package,
		    ';use Apache qw(exit);',
		    "\n#line 1 ", $r->filename, "\n",
		    $$code,
                    "\n";
    compile($r, \$eval);

    chdir $cwd;

    {   #flush the namespace
	no strict;
	%{$package.'::'} = ();
    }

    return error_check($r);
}

1;

__END__

=head1 NAME

Apache::PerlRun - Run unaltered CGI scripts under mod_perl

=head1 SYNOPSIS

 #in httpd.conf

 Alias /cgi-perl/ /perl/apache/scripts/ 
 PerlModule Apache::PerlRun

 <Location /cgi-perl>
 SetHandler perl-script
 PerlHandler Apache::PerlRun
 Options +ExecCGI 
 #optional
 PerlSendHeader On
 ...
 </Location>

=head1 DESCRIPTION

This module's B<handler> emulates the CGI environment,
allowing programmers to write scripts that run under CGI or
mod_perl without change.  Unlike B<Apache::Registry>, the
B<Apache::PerlRun> handler does not cache the script inside of a
subroutine.  Scripts will be "compiled" every request.  After the
script has run, it's namespace is flushed of all variables and
subroutines.

The B<Apache::Registry> handler is much faster than
B<Apache::PerlRun>.  However, B<Apache::PerlRun> is much faster than
CGI as the fork is still avoided and scripts can use modules which
have been pre-loaded at server startup time.  This module is meant for
"Dirty" CGI Perl scripts which relied on the single request lifetime
of CGI and cannot run under B<Apache::Registry> without cleanup.

=head1 SEE ALSO

perl(1), mod_perl(3), Apache::Registry(3)

=head1 AUTHOR

Doug MacEachern

