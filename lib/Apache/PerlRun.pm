package Apache::PerlRun;

use strict;
use Apache::Constants qw(:common OPT_EXECCGI);
use File::Basename ();
use IO::File ();
use Cwd ();

my $Is_Win32 = $^O eq "MSWin32";

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
    my $eval = shift;
    Apache->untaint($$eval);
    {
	no strict; #so eval'd code doesn't inherit our bits
	eval $$eval;
    }
}

sub namespace {
    my($r) = @_;
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

    return "Apache::ROOT$script_name";
}

sub readscript {
    my $r = shift;
    my $fh = IO::File->new($r->filename);
    local $/;
    my $code = <$fh>;
    #$code = parse_cmdline($code);
    return \$code;
}

sub status {
    my $r = shift;
    if ($@) {
	$r->log_error($@);
	$@{$r->uri} = $@;
	return SERVER_ERROR;
    }
    return OK;
}

sub handler {
    my $r = shift;

    my $rc = can_compile($r);
    return $rc unless $rc == OK;

    my $package = namespace($r);
    my $code = readscript($r);

    my $cwd = Cwd::fastcwd();
    chdir File::Basename::dirname($r->filename);
    *0 = \$r->filename;

    my $eval = join '',
		    'package ',
		    $package,
		    ';use Apache qw(exit);',
		    "\n#line 1 ", $r->filename, "\n",
		    $$code,
                    "\n";
    compile(\$eval);

    chdir $cwd;

    {   #flush the namespace
	no strict;
	%{$package.'::'} = ();
    }

    return status($r);
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

