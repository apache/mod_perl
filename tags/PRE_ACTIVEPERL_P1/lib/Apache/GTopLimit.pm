package Apache::GTopLimit;

=head1 NAME

Apache::GTopLimit - Limit Apache httpd processes 

=head1 SYNOPSIS

This module allows you to kill off Apache httpd processes if they grow
too large or have too little of shared memory.  You can choose to set
up the process size limiter to check the process size on every
request:

    # in your startup.pl:
    use Apache::GTopLimit;

    # Control the life based on memory size
    # in KB, so this is 10MB
    $Apache::GTopLimit::MAX_PROCESS_SIZE = 10000; 

    # Control the life based on Shared memory size
    # in KB, so this is 4MB 
    $Apache::GTopLimit::MIN_PROCESS_SHARED_SIZE = 4000; 

    # watch what happens
    $Apache::GTopLimit::DEBUG = 1;

    # in your httpd.conf:
    PerlFixupHandler Apache::GTopLimit
    # you can set this up as any Perl*Handler that handles 
    # part of the request, even the LogHandler will do.

Or you can just check those requests that are likely to get big or
unshared.  This way of checking is also easier for those who are
mostly just running Apache::Registry scripts:

    # in your CGI:
    use Apache::GTopLimit;
      # Max Process Size in KB
    Apache::GTopLimit->set_max_size(10000);	

and/or

    use Apache::GTopLimit;
       # Min Shared process Size in KB
    Apache::GTopLimit->set_min_shared_size(4000); 

Since accessing the process info might add a little overhead, you may
want to only check the process size every N times.  To do so, put this
in your startup.pl or CGI:

    $Apache::GTopLimit::CHECK_EVERY_N_REQUESTS = 2;

This will only check the process size every other time the process size
checker is called.

Note: The B<MAX_PROCESS_SIZE> and B<MIN_PROCESS_SHARED_SIZE> are
standalone, and each will be checked if only set. So if you set both
-- the process can be killed if it grows beyond the limit or its
shared memory goes below the limit.

=head1 DESCRIPTION

This module will run on platforms supported by B<GTop.pm> a Perl
interface to libgtop (which in turn needs B<libgtop> : See
http://home-of-linux.org/gnome/libgtop/ ).

This module was written in response to questions on the mod_perl mailing
list on how to tell the httpd process to exit if:

=over 4

=item *  

its memory size goes beyond a specified limit

=item *  

its shared memory size goes below a specified limit

=back

=head2 Limiting memory size

Actually there are two big reasons your httpd children will grow.  First,
it could have a bug that causes the process to increase in size
dramatically, until your system starts swapping.  Second, your process just
does stuff that requires a lot of memory, and the more different kinds of
requests your server handles, the larger the httpd processes grow over
time.

This module will not really help you with the first problem.  For that you
should probably look into Apache::Resource or some other means of setting a
limit on the data size of your program.  BSD-ish systems have setrlimit()
which will croak your memory gobbling processes.  However it is a little
violent, terminating your process in mid-request.

This module attempts to solve the second situation where your process
slowly grows over time.  The idea is to check the memory usage after every
request, and if it exceeds a threshold, exit gracefully.

By using this module, you should be able to discontinue using the
Apache configuration directive B<MaxRequestsPerChild>, although for
some folks, using both in combination does the job.  Personally, I
just use the technique shown in this module and set my
B<MaxRequestsPerChild> value to 6000.

=head2 Limiting shared memory size

We want the reverse the above limit for a shared memory limitation and
kill the process when its hs too little of shared memory.

When the same memory page is being shared between many processes, you
need less physical memory relative to the case where the each process
will have its own copy of the memory page. 

If your OS supports shared memory you will get a great benefit when
you deploy this feature. With mod_perl you enable it by preloading the
modules at the server startup. When you do that, each child uses the
same memory page as the parent does, after it forks. The memory pages
get unshared when a child modifies the page and it can no longer be
shared, that's when the page is being copied to the child's domain and
then modified as it pleased to. When this happens a child uses more
real memory and less shared.

Because of Perl's nature memory pages get unshared pretty fast, when
the code is being executed and it's internal data is being modified.
That's why as the child gets older the size of the shared memory goes
down.

You can tune your server to kill off the child when its shared memory
is too low, but it demands a constant retuning of the configuration
directives if you do any heavy updates in the code the server
executes. This module allows you to save up the time to make this
tuning and retuning, by simply specifying the minimum size of the
shared memory for each process. And when it crosses the line, to kill
it off.

=cut

use Apache::Constants qw(:common);
use Apache ();
# if you have GTop installed you will have Apache::GTopLimit working :)
use GTop ();
use strict;

$Apache::GTopLimit::VERSION = '0.03';
$Apache::GTopLimit::CHECK_EVERY_N_REQUESTS = 1;
$Apache::GTopLimit::REQUEST_COUNT = 1;
$Apache::GTopLimit::DEBUG = 0;

# init the GTop object
$Apache::GTopLimit::gtop = new GTop;

sub exit_if_too_big {
    my $r = shift;

    return if (++$Apache::GTopLimit::REQUEST_COUNT < $Apache::GTopLimit::CHECK_EVERY_N_REQUESTS);
    $Apache::GTopLimit::REQUEST_COUNT = 1;

      # Check the Memory Size if were requested
    if (defined($Apache::GTopLimit::MAX_PROCESS_SIZE)) {
	my $size = $Apache::GTopLimit::gtop->proc_mem($$)->size / 1024;
	warn "*** $size $Apache::GTopLimit::MAX_PROCESS_SIZE $Apache::GTopLimit::REQUEST_COUNT\n"
	  if $Apache::GTopLimit::DEBUG;
	if ($size > $Apache::GTopLimit::MAX_PROCESS_SIZE) {
	    # I have no idea if this will work on anything but UNIX
	    if (getppid > 1) {	# this is a  child httpd
		&error_log("httpd process is too big, exiting at SIZE=$size KB");
	        $r->child_terminate;
	    } else {		# this is the main httpd
		&error_log("main process is too big, SIZE=$size KB");
	    }
	}
    } else {
	&error_log("you didn't set \$Apache::GTopLimit::MAX_PROCESS_SIZE");
    }

      # Now check the Shared Memory Size if were requested
    if (defined($Apache::GTopLimit::MIN_PROCESS_SHARED_SIZE)) {
	my $size = $Apache::GTopLimit::gtop->proc_mem($$)->share / 1024;
	#warn "*** $size $Apache::GTopLimit::MIN_PROCESS_SHARE_SIZE $Apache::GTopLimit::REQUEST_COUNT\n"
	#  if $Apache::GTopLimit::DEBUG;
	if ($size < $Apache::GTopLimit::MIN_PROCESS_SHARED_SIZE) {
	    # I have no idea if this will work on anything but UNIX
	    if (getppid > 1) {	# this is a  child httpd
		&error_log("httpd process's shared memory is too low, exiting at SHARED SIZE=$size KB");
	        $r->child_terminate;
	    }
	    # we don't care about the parent's shared size, do we?
	}
    } else {
	&error_log("you didn't set \$Apache::GTopLimit::MIN_PROCESS_SHARE_SIZE");
    }
}

# set_max_size can be called from within a CGI/Registry script to tell the httpd
# to exit if the CGI causes the process to grow too big.
sub set_max_size {
    $Apache::GTopLimit::MAX_PROCESS_SIZE = shift;
    Apache->request->post_connection(\&exit_if_too_big);
}

# set_min_shared_size can be called from within a CGI/Registry script to tell the httpd
# to exit if the CGI causes the process to grow too big.
sub set_min_shared_size {
    $Apache::GTopLimit::MIN_PROCESS_SHARED_SIZE = shift;
    Apache->request->post_connection(\&exit_if_too_big);
}

sub handler {
    my $r = shift || Apache->request;
    $r->post_connection(\&exit_if_too_big)
	if ($r->is_main);
    return(DECLINED);
}

sub error_log {
    print STDERR "[", scalar(localtime(time)), "] ($$) Apache::GTopLimit: @_\n"
      if $Apache::GTopLimit::DEBUG;
}

1;

=head1 AUTHOR

Stas Bekman <sbekman@iname.com>:

An almost complete rewrite of Apache::SizeLimit toward using GTop
module (based on crossplatfom glibtop). The moment glibtop will be
ported on all the platforms Apache::SizeLimit runs at (I think only
Solaris is missing) Apache::SizeLimit will become absolete.

Doug Bagley wrote the original Apache::SizeLimit

=head1 CHANGES

$Id$

Tue Aug 17 07:32:20 IDT 1999

* Removed the use of global variables (save a few memory bits)

* Rewrite of the memory size limit functionality to use GTop

* Added a Shared memory limit functionality

* Added debug mode

=cut

