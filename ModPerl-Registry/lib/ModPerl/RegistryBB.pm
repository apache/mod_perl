package ModPerl::RegistryBB;

use strict;
use warnings FATAL => 'all';

# we try to develop so we reload ourselves without die'ing on the warning
no warnings qw(redefine); # XXX, this should go away in production!

our $VERSION = '1.99';

use ModPerl::RegistryCooker;
@ModPerl::RegistryBB::ISA = qw(ModPerl::RegistryCooker);

# META: prototyping ($$) segfaults on request
sub handler {
    my $class = (@_ >= 2) ? shift : __PACKAGE__;
    my $r = shift;
    return $class->new($r)->default_handler();
}

# currently all the methods are inherited through the normal ISA
# search may

1;
__END__

