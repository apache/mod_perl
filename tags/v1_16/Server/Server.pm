package Apache::Server;

use strict;

use DynaLoader ();
@Apache::Server::ISA = qw(DynaLoader);
$Apache::Server::VERSION = '1.00';

if ($ENV{MOD_PERL}) {
    bootstrap Apache::Server $Apache::Server::VERSION;
}

1;
__END__
