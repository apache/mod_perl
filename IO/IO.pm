package Apache::IO;

use strict;
use Apache ();
use vars qw($VERSION @ISA);

use DynaLoader ();
@ISA = qw(DynaLoader);

$VERSION = '1.00';

bootstrap Apache::IO $VERSION;

1;
__END__
