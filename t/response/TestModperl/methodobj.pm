package TestModperl::methodobj;

use strict;
use warnings FATAL => 'all';

use Apache::Const -compile => 'OK';

use TestModperl::method ();

our @ISA = qw(TestModperl::method);

1;
__END__
PerlResponseHandler $TestModperl::MethodObj->handler

