package Apache::Log;

use strict;
use Apache ();
use vars qw($VERSION @ISA);

use DynaLoader ();
@ISA = qw(DynaLoader Apache Apache::Server);

$VERSION = '1.00';

*Apache::log = *Apache::Server::log = \&log;
*emerg = \&emergency;
*crit  = \&critical;

sub log { 
    my $self = shift;
    my $s;
    if(ref $self) { 
	if($self->isa("Apache")) {
	    $s = $self->server;
	}
	elsif($self->isa("Apache::Server")) {
	    $s = $self;
	}
	else {
	    die("Can't pull an Apache::Server from $self");
	}
    }
    else {
	$s = Apache->request->server;
    }
    bless $s; 
}

if($ENV{MOD_PERL}) {
    bootstrap Apache::Log $VERSION;
}

1;
__END__

=head1 NAME

Apache::Log - Interface to Apache logging

=head1 SYNOPSIS

  use Apache::Log ();
  my $log = $r->log;
  $log->debug("You only see this if `LogLevel' is set to `debug'");

=head1 DESCRIPTION

The Apache::Log module provides an interface to Apache's I<ap_log_error>
routine.

=over 4

=item emerg

=item alert

=item crit

=item error

=item warn

=item notice

=item info

=item debug

=back

=head1 AUTHOR

Doug MacEachern

=head1 SEE ALSO

mod_perl(3), Apache(3).

=cut
