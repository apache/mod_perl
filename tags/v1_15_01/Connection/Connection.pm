package Apache::Connection;

use strict;

use DynaLoader ();
@Apache::Connection::ISA = qw(DynaLoader);
$Apache::Connection::VERSION = '1.00';

if ($ENV{MOD_PERL}) {
    bootstrap Apache::Connection $Apache::Connection::VERSION;
}

1;
__END__
