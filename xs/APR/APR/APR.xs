#include "mod_perl.h"

#ifdef MP_HAVE_APR_LIBS
#   define APR_initialize apr_initialize
#   define APR_terminate  apr_terminate
#else
#   define APR_initialize()
#   define APR_terminate()
#endif

MODULE = APR    PACKAGE = APR

PROTOTYPES: disable

BOOT:
    file = file; /* -Wall */
    APR_initialize();

void
END()

    CODE:
    APR_terminate();
