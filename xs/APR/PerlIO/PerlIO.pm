package APR::PerlIO;

require 5.006001;

our $VERSION = '0.01';

# The PerlIO layer is available only since 5.8.0 (5.7.2@13534)
use Config;
use constant PERLIO_LAYERS_ARE_ENABLED => $Config{useperlio} && $] >= 5.00703;

use APR::XSLoader ();
APR::XSLoader::load __PACKAGE__;


1;
