package Apache::PerlRunXS;

use strict;
use vars qw($Debug $VERSION @ISA);
use Apache::Constants qw(:common);

unless (defined $Apache::Registry::NameWithVirtualHost) {
    $Apache::Registry::NameWithVirtualHost = 1;
}

$Debug ||= 0;
my $Is_Win32 = $^O eq "MSWin32";

$VERSION = '0.03';
#@ISA = qw(DynaLoader);

if($ENV{MOD_PERL}) {
    bootstrap Apache::PerlRunXS $VERSION;
}

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
    $r->log_error("Apache::PerlRunXS->new for $filename in process $$")
	if $Debug && $Debug & 4;

    bless $r, $class;
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

