package Apache::Registry;
use Apache ();
#use strict; #eval'd scripts will inherit hints
use Apache::Constants qw(:common &OPT_EXECCGI &REDIRECT);
use FileHandle ();
use File::Basename ();
use Cwd ();

#$Id$
$Apache::Registry::VERSION = (qw$Revision$)[1];

$Apache::Registry::Debug ||= 0;
# 1 => log recompile in errorlog
# 2 => Apache::Debug::dump in case of $@
# 4 => trace pedantically
Apache->module('Apache::Debug') if $Apache::Registry::Debug;

my $Is_Win32 = $^O eq "MSWin32";

sub handler {
    my $r = shift;
    if(ref $r) {
	$r->request($r);
    }
    else {
	#warn "Registry args are: ($r, @_)\n";
	$r = Apache->request;
    }
    my $filename = $r->filename;
    #local $0 = $filename; #this core dumps!?
    *0 = \$filename;
    my $oldwarn = $^W;
    $r->log_error("Apache::Registry::handler for $filename in process $$")
	if $Debug && $Debug & 4;

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

	my $mtime = -M _;

	# turn into a package name
	$r->log_error(sprintf "Apache::Registry::handler examining %s",
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

	my $package = "Apache::ROOT$script_name";
	$Apache::Registry::curstash = $script_name;
	$r->log_error("Apache::Registry::handler package $package")
	   if $Debug && $Debug & 4;


	my $cwd = Cwd::fastcwd();
	chdir File::Basename::dirname($r->filename);

	if (
	    exists $Apache::Registry->{$package}{'mtime'}
	    &&
	    $Apache::Registry->{$package}{'mtime'} <= $mtime
	   ){
	    # we have compiled this subroutine already, nothing left to do
 	} else {
	    $r->log_error("Apache::Registry::handler reading $filename")
		if $Debug && $Debug & 4;
	    my($sub);
	    {
		my $fh = FileHandle->new($filename);
		local $/;
		$sub = <$fh>;
		$sub = parse_cmdline($sub);
	    }

	    # compile this subroutine into the uniq package name
            $r->log_error("Apache::Registry::handler eval-ing") if $Debug && $Debug & 4;
 	    undef &{"$package\::handler"} unless $Debug && $Debug & 4; #avoid warnings
	    if($package->can('undef_functions')) {
		$package->undef_functions;
	    }
	    $r->clear_rgy_endav($script_name);

	    my $eval = join(
			    '',
			    'package ',
			    $package,
 			    ';use Apache qw(exit);',
 			    'sub handler {',
 			    "\n#line 1 $filename\n",
			    $sub,
			    "\n}", # last line comment without newline?
			   );
	    compile($eval);
	    if ($@) {
		$r->log_error($@);
		$@{$r->uri} = $@;
		return SERVER_ERROR unless $Debug && $Debug & 2;
		return Apache::Debug::dump($r, SERVER_ERROR);
	    }
            $r->log_error(qq{Compiled package \"$package\" for process $$})
	       if $Debug && $Debug & 1;
	    $Apache::Registry->{$package}{'mtime'} = $mtime;
	}

	my $cv = \&{"$package\::handler"};
	eval { &{$cv}($r, @_) } if $r->seqno;
	{
	    local $^W = 0; #shutup Cwd.pm
	    chdir $cwd;
	}
	$^W = $oldwarn;

	my $errsv = "";
	if($@) {
	    $errsv = $@;
	    $@ = ''; #XXX fix me, if we don't do this Apache::exit() breaks
	    $@{$r->uri} = $errsv;
	}

	if($errsv) {
	    $r->log_error($errsv);
	    return SERVER_ERROR unless $Debug && $Debug & 2;
	    return Apache::Debug::dump($r, SERVER_ERROR);
	}

=pod
	#XXX
	if(my $loc = $r->header_out("Location")) {
	    if($r->status == 200 and substr($loc, 0, 1) ne "/") {
		return REDIRECT;
	    }
	}
=cut
	return $r->status;
    } else {
	return NOT_FOUND unless $Debug && $Debug & 2;
	return Apache::Debug::dump($r, NOT_FOUND);
    }
}

sub compile {
    my $eval = shift;
    Apache->untaint($eval);
    eval $eval;
}

#XXX not good enough yet
my(%switches) = (
   'T' => sub {
       Apache::warn("Apache::Registry: T switch ignored, ".
		    "enable with 'PerlTaintCheck On'\n")
	   unless $Apache::__T; "";
   },
   'w' => sub { 'BEGIN {$^W = 1;}' },
);

sub parse_cmdline {
    my $sub = shift;
    my($line) = $sub =~ /^(.*)$/m;
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
    $sub =~ s/^/$prepend/ if $prepend;
    return $sub;
}

#trick so we show up under CPAN/modules/by-module/CGI/
package CGI::mod_perl;

sub DESTROY {}

1;

__END__

=head1 NAME

Apache::Registry - Run unaltered CGI scrips under mod_perl

=head1 SYNOPSIS

 #in httpd.conf

 Alias /perl/ /perl/apache/scripts/ #optional
 PerlModule Apache::Registry

 <Location /perl>
 SetHandler perl-script
 PerlHandler Apache::Registry
 Options ExecCGI 
 ...
 </Directory>

=head1 DESCRIPTION

URIs in the form of C<http://www.host.com/perl/file.pl> will be
compiled as the body of a perl subroutine and executed.  Each server
process or 'child' will compile the subroutine once and store it in
memory. It will recompile it whenever the file is updated on disk.
Think of it as an object oriented server with each script implementing
a class loaded at runtime.

The file looks much like a "normal" script, but it is compiled or 'evaled'
into a subroutine.

Here's an example:

 my $r = Apache->request;
 $r->content_type("text/html");
 $r->send_http_header;
 $r->print("Hi There!");

This module emulates the CGI environment,
allowing programmers to write scripts that run under CGI or
mod_perl without change.  Existing CGI scripts may require some
changes, simply because a CGI script has a very short lifetime of one
HTTP request, allowing you to get away with "quick and dirty"
scripting.  Using mod_perl and Apache::Registry requires you to be
more careful, but it also gives new meaning to the word "quick"!

Be sure to read all mod_perl related documentation for more details,
including instructions for setting up an environment that looks exactly
like CGI:

 print "Content-type: text/html\n\n";
 print "Hi There!";

Note that each httpd process or "child" must compile each script once,
so the first request to one server may seem slow, but each request
there after will be faster.  If your scripts are large and/or make use
of many Perl modules, this difference should be noticeable to the human
eye.

=head1 SECURITY

Apache::Registry::handler will preform the same checks as mod_cgi
before running the script.

=head1 ENVIRONMENT

The Apache function `exit' overrides the Perl core built-in function.

The environment variable B<GATEWAY_INTERFACE> is set to C<CGI-Perl/1.1>.

=head1 COMMANDLINE SWITCHES IN FIRST LINE

Normally when a Perl script is run from the command line or under CGI,
arguments on the `#!' line are passed to the perl interpreter for processing.

Apache::Registry currently only honors the B<-w> switch and will turn
on warnings using the C<$^W> global variable.  Another common switch
used with CGI scripts is B<-T> to turn on taint checking.  This can
only be enabled when the server starts with the configuration
directive:

 PerlTaintCheck On

However, if taint checking is not enabled, but the B<-T> switch is seen,
Apache::Registry will write a warning to the error_log.

=head1 DEBUGGING

You may set the debug level with the $Apache::Registry::Debug bitmask

 1 => log recompile in errorlog
 2 => Apache::Debug::dump in case of $@
 4 => trace pedantically

=head1 CAVEATS

Apache::Registry makes things look just the CGI environment, however, you
must understand that this *is not CGI*.  Each httpd child will compile
your script into memory and keep it there, whereas CGI will run it once,
cleaning out the entire process space.  Many times you have heard
"always use C<-w>, always use C<-w> and 'use strict'".
This is more important here than anywhere else!

Your scripts cannot contain the __END__ or __DATA__ token to terminate
compilation.

=head1 SEE ALSO

perl(1), mod_perl(3), Apache(3), Apache::Debug(3)

=head1 AUTHORS

Andreas J. Koenig and Doug MacEachern

