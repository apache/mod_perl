package Apache::Const;

use ModPerl::Const ();
use XSLoader ();

our $VERSION = '0.01';
our @ISA = qw(ModPerl::Const);

XSLoader::load(__PACKAGE__, $VERSION);

#XXX: we don't support string constants in the lookup functions
#always define this one for the moment
sub Apache::DIR_MAGIC_TYPE () { "httpd/unix-directory" }

1;
