package Apache::fork;

use strict;
use Exporter ();
@Apache::fork::EXPORT = qw(fork forkoption);
$Apache::fork::VERSION = '1.00';

*import = \&Exporter::import;

if($ENV{MOD_PERL}) {
    *fork = \&Apache::fork;
    *forkoption = \&Apache::forkoption;
}
else {
    *forkoption = sub {};
    *fork = \&CORE::fork;
}

1;

__END__

=pod

=head1 NAME

Apache::fork - Override Perl's built-in fork()

=head1 SYNOPSIS

 use Apache::fork;

=head1 DESCRIPTION

The B<fork> function defined in this module will override Perl's
built-in B<fork> function so that any children resulting from a fork()
will (optionally) close any open listening http sockets (main server
and virtuals) and/or kill the child httpd process with exit() is called.

TOGGLING:
forkoption(int) usage:

int can be one of the following...

0 = Nothing, perform your normal fork().
1 = Have the child resulting from a fork close all listening sockets.
2 = Have the child resulting from a fork() die with exit() is called.
3 = Do both 1 and 2.

Default is 3.

NOTE: forkoption is NOT reset to default between hits, why?  So you 
could set it in a perlscript and have it last across clients/runs (ie
so you wouldn't need to go modifying your mod_perl (or in my case,
pure CGI/perl scripts. ;)

ALSO NOTE: The parent process will still have the http sockets open, so
it can still communicate with the downstream client, as well as still
accept connections after the client has disconnected, it's only the
resulting child who will no longer have the http sockets open.

ANOTHER NOTE: The child STILL has the socket open to the client, it's 
just the listening sockets (port 80, etc) that's closed.

AYA NOTE: ALL listening sockets are closed, for the main server AND
for any alternative ports you have the httpd process listening to.

WHY?: Sometimes, you want to have your script fork, then exec a process
so that it can perform some nifty thing in the background.  Unfortunatly,
when you fork (and exec), all open file descriptors are passed along, 
including the listening HTTP sockets that are used by the server to
accept connections, which can be a bad thing.  (ie.  Child is forked, 
forked child has port 80 open, forked child exec()'s whatever, now
whatever has port 80 open, server is HUP'd, restarted, whatever...
'course, it can't because some other process already has control over
port 80 (ie, whatever)) Ow?  ;)

Also, forked children would "hang around" when they were finished (or 
exit()'d) unless exit(-2) was used.  And, the original parent httpd
had no clue the children even existed.  Essentually, you'd end up
with an indefinite number of httpd processes (as each forked()'d child
would never exit).  Of course, with the socket closing patch in
place... those children never again served another page either.

This patch was made essentually to make fork() under mod_perl act
like you'd expect it to (so modules that might be used by non-mod_perl
scripts wouldn't need to be modified)

Incase any of you were curious, all my CGI scripts run unmodified under
mod_perl.  Not a single line of mod_perl anything in them.  If they
won't work under mod_perl for some odd reason, I just modify mod_perl
so they do.  ;)

=head1 AUTHOR

Michael Turner, mturner@spry.com

=cut
