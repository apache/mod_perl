package Apache::SIG;

use strict;
$Apache::SIG::VERSION = (qw$Revision$)[1];

sub handler {
    $SIG{PIPE} = \&PIPE;
}

sub PIPE {
    my $ppid = getppid;
    my $s = ($ppid > 1) ? -2 : 0;
    warn "Client hit STOP or Netscrape bit it!\n";
    warn "Process $$ going to Apache::exit with status=$s\n";
    Apache::exit($s);  
}

*set = \&handler;

1;

__END__

=pod

=head1 NAME

Apache::SIG - Override apache signal handlers with Perl's

=head1 SYNOPSIS

 #PerlScript

 use Apache::SIG ();
 Apache::SIG->set;

=head1 DESCRIPTION

When a client drops a connection and apache is in the middle of a
write, a timeout will occur and httpd sends a B<SIGPIPE>.  When
apache's SIGPIPE handler is used, Perl may be left in the middle of
it's eval context, causing bizarre errors during subsequent requests
are handled by that child.  When Apache::SIG is used, it installs a
different SIGPIPE handler which rewinds the context to make sure Perl
is back to normal state, preventing these bizarre errors.

=head1 AUTHOR

Doug MacEachern

=head1 SEE ALSO

perlvar(1)
    
=cut
