package APR::Const;

use ModPerl::Const ();
use XSLoader ();

our $VERSION = '0.01';
our @ISA = qw(ModPerl::Const);

XSLoader::load(__PACKAGE__, $VERSION);

1;
