#include "mod_perl.h"
#include "apr_perlio.h"

MODULE = APR::PerlIO    PACKAGE = APR::PerlIO

PROTOTYPES: disabled

BOOT:
    apr_perlio_init(aTHX);
