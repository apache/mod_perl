package APR::PerlIO;

require 5.6.1;

our $VERSION = '0.01';

use APR::XSLoader ();
APR::XSLoader::load __PACKAGE__;

# XXX: The PerlIO layer is available only since 5.8.0 (5.7.2 p13534)

1;
